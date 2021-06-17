module Unpoly
  module Guide
    class Parser
      include Logger

      class Error < StandardError; end
      class CannotParse < Error; end
      class MissingVisibility < CannotParse; end

      BLOCK_PATTERN = %r{
        ^[\ \t]*\#\#\#\*[\ \t]*\n  # YUIDoc begin symbol
        ((?:.|\n)*?)               # block content ($1)
        ^[\ \t]*\#\#\#[\ \t]*\n    # YUIDoc end symbol
      }x

      INTERFACE_PATTERN = %r{
        \@(class|module|page)  # kind ($1)
        \                      # space
        (.+)                   # class name ($2)
      }x

      TITLE_PATTERN = %r{
        \A         # beginning of text
        [\ \t\n]*  # whitespace and line breaks
        (.+)       # title ($1)
        \n         # line break
        \={3,}     # markdown h1 underline
        (\n|$)     # line break or EOF
      }x

      FEATURE_PATTERN = %r{
        \@(function|selector|event|property|constructor|header|cookie)  # @function or @selector or ... ($1)
        \                                                               # space
        (.+)                                                            # feature name ($2)
      }x

      VISIBILITY_PATTERN = %r{
        (^[ \t]*)        # first line indent ($1)
        \@(              # visibility ($2)
          stable|
          experimental|
          internal|
          deprecated
        )
        (                # visibility comment, mostly for deprecation ($3)
          .*$            # .. remainder of first line
          (?:
            \n
            (?:
              \1[\ \t]+  # .. subsequent lines that are indented further than the first line
              .*
              |
              [\ \t]*    # ... or an entirely blank line, even if it is not indented enough
            )
            $
          )*
        )
      }x

      # ESSENTIAL_PATTERN = %r{
      #   (^[ \t]*)        # first line indent ($1)
      #   \@(              # essential tag ($2)
      #     essential
      #   )
      # }x

      PARAMS_NOTE_PATTERN = %r{
        (^[ \t]*)        # first line indent ($1)
        \@(params-note)  # tag ($2)
        (                # note markdown ($3)
          .*$            # .. remainder of first line
          (?:
            \n
            (?:
              \1[\ \t]+  # .. subsequent lines that are indented further than the first line
              .*
              |
              [\ \t]*    # ... or an entirely blank line, even if it is not indented enough
            )
            $
          )*
        )
      }x

      TYPES_PATTERN = %r{
      \{          # opening brace
        ([^\}]+)  # pipe-separated list of types ($1)
        \}        # closing brace
      }x

      TYPES_SEPARATOR = %r{
        [\ \t]*  # whitespace
        \|       # pipe symbol
        [\ \t]*  # whitespace
      }x

      RESPONSE_PATTERN = %r{
        (^[ \t]*)      # first line indent ($1)
        \@return       # @return
        (              # response spec ($2)
          .*$          # .. remainder of first line
          (?:
            \n
            (?:
              \1[\ \t]+  # .. subsequent lines that are indented further than the first line
              .*
              |
              [\ \t]*    # ... or an entirely blank line, even if it is not indented enough
            )
            $
          )*
        )
      }x

      PARAM_PATTERN = %r{
        (^[ \t]*)      # first line indent ($1)
        \@param\b      # @param, but not @params-note
        (              # param spec ($2)
          .+$          # .. remainder of first line
          (?:
            \n
            (?:
              \1[\ \t]+  # .. subsequent lines that are indented further than the first line
              .*
              |
              [\ \t]*    # ... or an entirely blank line, even if it is not indented enough
            )
            $
          )*
        )
      }x

      PARAM_NAME_PATTERN = %r{
        (?:
          \[           # opening bracket
          [\ \t]*      # whitespace
          ([^\ \t\=]+)   # optional param name ($1)
          (?:
            [\ \t]*        # .. whitespace before equals symbol
            \=             # .. equals symbol
            [\ \t]*        # .. whitespace after equals symbol
            (\'.*?\'|\".*?\"|\[.*?\]|.+?)  # .. default value which might be a string or an array with square brackets ($2)
          )?
          [\ \t]*      # whitespace
          \]           # closing bracket
        )
        |
        ([^\ \t]+)      # required param name ($3)
      }x

      REFERENCE_PATTERN = %r{
        \@see
        \s+
        (.+?) # guide ID ($1)
        (\n|$)
      }x

      # EXAMPLE_PATTERN = %r{
      #   (^[ \t]*)     # first line indent ($1)
      #   \@example     # @example
      #   (             # example body ($1)
      #     .+\n        # .. remainder of first line
      #     \1[\ \t]+   # .. subsequent lines that are indented further than the first line
      #   )
      # }x

      def initialize(repository)
        @repository = repository
        @last_interface = nil
      end

      def parse(path)
        doc_comments = DocComment.find_in_path(path)
        doc_comments.each do |doc_comment|
          if documentable = parse_interface!(doc_comment.text) || parse_feature!(doc_comment)
            documentable.text_source = doc_comment.text_source
          end
        end
      end

      private

      def parse_interface!(block)
        if block.sub!(INTERFACE_PATTERN, '')
          interface_kind = $1.strip
          interface_name = $2.strip
          interface = Interface.new(interface_kind, interface_name)
          block = Util.unindent(block)

          if explicit_title = parse_title!(block)
            interface.explicit_title = explicit_title
          end

          parse_references!(block, interface)

          # All the remaining text is guide prose
          interface.guide_markdown = process_markdown(block)

          interface = @repository.merge_interface(interface)
          @last_interface = interface
          interface
        end
      end

      def parse_feature!(doc_comment)
        text = doc_comment.text

        if text.sub!(FEATURE_PATTERN, '')
          feature_kind = $1.strip
          feature_name = $2.strip
          text = Util.unindent(text)

          feature = Feature.new(feature_kind, feature_name)

          if visibility = parse_visibility!(text)
            feature.visibility = visibility[:visibility]
            feature.visibility_comment = visibility[:comment]
          elsif looks_like_published_feature?(feature_name)
            raise MissingVisibility, "Missing visibility tag for feature: @#{feature_kind} #{feature_name} (#{doc_comment.local_position})"
          end

          while param = parse_param!(text)
            param.feature = feature
            feature.params << param
          end

          if response = parse_response!(text)
            feature.response = response
          end

          # feature.essential = parse_essential!(block)

          parse_references!(text, feature)

          feature.params_note = parse_params_note!(text)

          # while example = parse_example(block)
          #   feature.examples << example
          # end
          # All the remaining text is guide prose
          feature.guide_markdown = process_markdown(text)
          feature.interface = @last_interface
          @last_interface.features << feature
          feature
        end
      end

      def parse_visibility!(block)
        if block.sub!(VISIBILITY_PATTERN, '')
          { visibility: $2, comment: $3 }
        end
      end

      def parse_params_note!(block)
        if block.sub!(PARAMS_NOTE_PATTERN, '')
          note = $3
          note
        end
      end

      def parse_title!(block)
        if block.sub!(TITLE_PATTERN, '')
          title = $1
          title
        end
      end

      # def parse_essential!(block)
      #   !!block.sub!(ESSENTIAL_PATTERN, '')
      # end

      def parse_param!(block)
        if block.sub!(PARAM_PATTERN, '')
          param_spec = Util.unindent($2)
          param = Param.new
          if types = parse_types!(param_spec)
            param.types = types
          end
          if name_props = parse_param_name_and_optionality!(param_spec)
            param.name = name_props[:name].strip
            param.optional = name_props[:optional] if name_props.has_key?(:optional)
            param.default = name_props[:default] if name_props.has_key?(:default)
          end

          markdown = process_markdown(Util.unindent_hanging(param_spec))

          parse_references!(markdown, param)

          param.guide_markdown = markdown
          param
        end
      end

      def parse_references!(block, referencer)
        while reference_name = parse_reference_name!(block)
          referencer.reference_names << reference_name
        end
      end

      def parse_reference_name!(block)
        if block.sub!(REFERENCE_PATTERN, '')
          return $1
        end
      end

      def parse_response!(block)
        if block.sub!(RESPONSE_PATTERN, '')
          response_spec = Util.unindent($2)
          response = Response.new
          if types = parse_types!(response_spec)
            response.types = types
          end
          markdown = process_markdown(Util.unindent_hanging(response_spec))
          response.guide_markdown = markdown
          response
        end
      end

      # A param's name, optional/required property and
      # eventual default value are so interwoven syntax-wise
      # that we parse all three with a single method.
      def parse_param_name_and_optionality!(param_spec)
        if param_spec.sub!(PARAM_NAME_PATTERN, '')
          optional_param_name = $1
          default_value = $2
          required_param_name = $3

          # raise "WTF" if optional_param_name && optional_param_name.include?('=')
          # log("param name", optional_param_name, default_value, required_param_name)

          if required_param_name
            { name: required_param_name,
              optional: false }
          else
            { name: optional_param_name,
              optional: true,
              default: default_value }
          end
        end
      end

      def parse_ujs!(block)
        if block.sub!(UJS_PATTERN, '')
          true
        end
      end

      def parse_property!(block)
        if block.sub!(PROPERTY_PATTERN, '')
          true
        end
      end

      def parse_event!(block)
        if block.sub!(EVENT_PATTERN, '')
          true
        end
      end

      def parse_types!(block)
        if block.sub!(TYPES_PATTERN, '')
          types = $1.split(TYPES_SEPARATOR)
          types
        end
      end
      
      def process_markdown(markdown)
        # We cannot use triple-hashes for h3 since
        # that would close CS block comments
        markdown.gsub /(\\#){2,}/ do |match|
          "#" * (match.size / 2)
        end
      end

      def looks_like_published_feature?(feature_name)
        feature_name =~ /^up[\.\:]/
      end

    end

  end
end
