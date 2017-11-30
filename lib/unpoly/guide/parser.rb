module Unpoly
  module Guide
    class Parser
      include Logger

      class CannotParse < StandardError; end

      BLOCK_PATTERN = %r{
        ^[\ \t]*\#\#\#\*[\ \t]*\n  # YUIDoc begin symbol
        ((?:.|\n)*?)               # block content ($1)
        ^[\ \t]*\#\#\#[\ \t]*\n    # YUIDoc end symbol
      }x

      KLASS_PATTERN = %r{
        \@(class)  # @class ($1)
        \          # space
        (.+)       # class name ($2)
      }x

      TITLE_PATTERN = %r{
        \A         # beginning of text
        [\ \t\n]*  # whitespace and line breaks
        (.+)       # title ($1)
        \n         # line break
        \={3,}     # markdown h1 underline
        \n         # line break
      }x

      FEATURE_PATTERN = %r{
        \@(function|selector|event|property|constructor)  # @function or @selector or ... ($1)
        \                                                 # space
        (.+)                                              # feature name ($2)
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
        \@param        # @param
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
        @last_klass = nil
      end

      def parse(path)
        doc_comments = DocComment.find_in_path(path)
        doc_comments.each do |doc_comment|
          if documentable = parse_klass!(doc_comment.text) || parse_feature!(doc_comment.text)
            documentable.text_source = doc_comment.text_source
          end
        end
      end

      private

      def parse_klass!(block)
        if block.sub!(KLASS_PATTERN, '')
          klass_kind = $1.strip
          klass_name = $2.strip
          klass = Klass.new(klass_kind, klass_name)
          # if visibility = parse_visibility!(block)
          #   klass.visibility = visibility
          # end
          if title = parse_title!(block)
            klass.title = title
          end
          # All the remaining text is guide prose
          klass.guide_markdown = process_markdown(block)
          @repository.klasses << klass
          @last_klass = klass
          klass
        end
      end

      def parse_feature!(block)
        if block.sub!(FEATURE_PATTERN, '')
          feature_kind = $1.strip
          feature_name = $2.strip
          feature = Feature.new(feature_kind, feature_name)
          if visibility = parse_visibility!(block)
            feature.visibility = visibility[:visibility]
            feature.visibility_comment = visibility[:comment]
          end
          while param = parse_param!(block)
            param.feature = feature
            feature.params << param
          end
          if response = parse_response!(block)
            feature.response = response
          end
          # while example = parse_example(block)
          #   feature.examples << example
          # end
          # All the remaining text is guide prose
          feature.guide_markdown = process_markdown(block)
          feature.klass = @last_klass
          @last_klass.features << feature
          feature
        end
      end

      def parse_visibility!(block)
        if block.sub!(VISIBILITY_PATTERN, '')
          { visibility: $2, comment: $3 }
        end
      end

      def parse_title!(block)
        if block.sub!(TITLE_PATTERN, '')
          title = $1
          title
        end
      end

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

          param.guide_markdown = process_markdown(Util.unindent_hanging(param_spec))
          param
        end
      end

      def parse_response!(block)
        if block.sub!(RESPONSE_PATTERN, '')
          response_spec = Util.unindent($2)
          response = Response.new
          if types = parse_types!(response_spec)
            response.types = types
          end
          response.guide_markdown = process_markdown(Util.unindent_hanging(response_spec))
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

    end

  end
end
