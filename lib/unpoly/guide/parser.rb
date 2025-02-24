module Unpoly
  module Guide
    class Parser
      include Logger
      include Memoized

      class Error < StandardError; end
      class CannotParse < Error; end
      class CannotMerge < Error; end
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

      EXPLICIT_PARENT_PATTERN = %r{
        \@parent
        \                      # space
        (.+)                   # parent interface name ($1)
      }x

      TITLE_PATTERN = %r{
        \A         # beginning of text
        [\ \t\n]*  # whitespace and line breaks
        (.+)       # title ($1)
        \n         # line break
        \={3,}     # markdown h1 underline
        (\n|$)     # line break or EOF
      }x

      MENU_TITLE_PATTERN = %r{
        \@menu-title    # @menu-title
        \               # space
        (.+)            # title
        (\n|$)          # line break or EOF
      }x

      PARTIAL_PATTERN = %r{
        \@partial  # @partial
        \          # space
        (.+)       # partial name ($1)
      }x

      INCLUDE_PATTERN = %r{
        ^([ \t]*)  # indent ($1)
        \@include  # @include
        \          # space
        (.+)       # partial name ($2)
        (\n|\z)    # remove line feed as partial markdown already ends in line feed
      }x

      LIKE_PATTERN = %r{
        \@like          # @like
        \               # space
        ([^\ ]+)        # index_name of referenced documentable ($1)
        [\ \t]*         # trailing spaces and tabs
        (\n|$)          # line break or EOF
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
        (                   # optional type ($2, $3)
          [ \t]+
          #{TYPES_PATTERN}
        )?
        (              # response spec ($4)
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
        (                   # optional type ($2, $3)
          [ \t]+
          #{TYPES_PATTERN}
        )?
        (              # param spec ($4)
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

        # TODO: We already know the repository. We don't need to track documentables ourselves.
        @documentables_by_index_name = {}
      end

      def parse_all(paths)
        paths.each do |source_path|
          parse(source_path)
        end

        documentables.each do |documentable|
          postprocess!(documentable)
        end
      end

      private

      def parse(path)
        doc_comments = DocComment.find_in_path(path)
        doc_comments.each do |doc_comment|
          documentables_from_comment = parse_interface!(doc_comment) || parse_feature!(doc_comment) || parse_partial!(doc_comment) || cannot_parse!(doc_comment)
          documentables_from_comment.each do |documentable|
            documentable.text_source = doc_comment.text_source
            index_documentable(documentable)
          end
        end
      end

      def index_documentable(documentable)
        @documentables_by_index_name[documentable.index_name] = documentable
      end

      def find_by_index_name!(index_name)
        index_name = index_name.sub('#', '.prototype.')
        @documentables_by_index_name.fetch(index_name)
      end

      def documentables
        @documentables_by_index_name.values
      end

      def parse_partial!(doc_comment)
        text = doc_comment.text

        if text.sub!(PARTIAL_PATTERN, '')
          partial_name = $1.strip

          partial = Partial.new(partial_name)
          text = Util.unindent(text)
          text = text.strip + "\n"
          partial.guide_markdown = text

          [partial]
        end
      end

      def parse_interface!(doc_comment)
        block = doc_comment.text

        if block.sub!(INTERFACE_PATTERN, '')
          interface_kind = $1.strip
          interface_name = $2.strip
          interface = Interface.new(interface_kind, interface_name)
          block = Util.unindent(block)

          if (explicit_title = parse_title!(block))
            interface.explicit_title = explicit_title
          end

          if (explicit_menu_title = parse_menu_title!(block))
            interface.explicit_menu_title = explicit_menu_title
          end

          if (visibility = parse_visibility!(block))
            interface.visibility = visibility[:visibility]
            interface.visibility_comment = visibility[:comment]
          end

          parse_references!(block, interface)

          parse_explicit_parent!(block, interface)

          # All the remaining text is guide prose
          interface.guide_markdown = block

          interface = @repository.merge_interface(interface)
          @last_interface = interface
          [interface]
        end
      end

      def parse_feature!(doc_comment)
        text = doc_comment.text

        if text.sub!(FEATURE_PATTERN, '')
          feature_kind = $1.strip
          feature_name = $2.strip
          text = Util.unindent(text)

          feature = Feature.new(feature_kind, feature_name)

          while (param = parse_param!(text))
            param.feature = feature
            feature.params << param
          end

          if (response = parse_response!(text))
            feature.response = response
            response.feature = feature
          end

          if (visibility = parse_visibility!(text))
            feature.visibility = visibility[:visibility]
            feature.visibility_comment = visibility[:comment]
          elsif looks_like_published_feature?(feature_name)
            raise MissingVisibility, "Missing visibility tag for feature: @#{feature_kind} #{feature_name} (#{doc_comment.local_position})"
          end

          # feature.essential = parse_essential!(block)

          parse_references!(text, feature)

          feature.params_note = parse_params_note!(text)

          # while example = parse_example(block)
          #   feature.examples << example
          # end
          # All the remaining text is guide prose
          feature.guide_markdown = text
          feature.interface = @last_interface
          @last_interface.features << feature

          [feature, *feature.params, feature.response].compact
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

      def parse_like_name!(block)
        if block.sub!(LIKE_PATTERN, '')
          name = $1
          name
        end
      end

      def parse_title!(block)
        if block.sub!(TITLE_PATTERN, '')
          title = $1
          title
        end
      end

      def parse_menu_title!(block)
        if block.sub!(MENU_TITLE_PATTERN, '')
          menu_title = $1
          menu_title
        end
      end

      # def parse_essential!(block)
      #   !!block.sub!(ESSENTIAL_PATTERN, '')
      # end

      def parse_param!(block)
        if block.sub!(PARAM_PATTERN, '')
          type_spec = $2
          param_spec = Util.unindent($4)
          param = Param.new

          if (types = parse_types!(type_spec))
            param.types = types
          end

          if (name_props = parse_param_name_and_optionality!(param_spec))
            param.name = name_props[:name].strip
            param.optional = name_props[:optional] if name_props.has_key?(:optional)
            param.default = name_props[:default] if name_props.has_key?(:default)
          end

          if (visibility = parse_visibility!(param_spec))
            param.explicit_visibility = visibility[:visibility]
            param.visibility_comment = visibility[:comment]
          end

          if (like_name = parse_like_name!(param_spec))
            param.like_name = like_name
          end

          markdown = Util.unindent_hanging(param_spec)

          parse_references!(markdown, param)

          param.guide_markdown = markdown
          param
        end
      end

      def parse_references!(block, referencer)
        while (reference_name = parse_reference_name!(block))
          referencer.reference_names << reference_name
        end
      end

      def parse_explicit_parent!(block, documentable)
        if block.sub!(EXPLICIT_PARENT_PATTERN, '')
          documentable.explicit_parent_name = $1
        end
      end

      def parse_reference_name!(block)
        if block.sub!(REFERENCE_PATTERN, '')
          return $1
        end
      end

      def parse_response!(block)
        if block.sub!(RESPONSE_PATTERN, '')
          type_spec = $2
          response_spec = Util.unindent($4)
          response = Response.new

          if (types = parse_types!(type_spec))
            response.types = types
          end

          if (like_name = parse_like_name!(response_spec))
            response.like_name = like_name
          end

          markdown = Util.unindent_hanging(response_spec)
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
          probably_required_param_name = $3

          # raise "WTF" if optional_param_name && optional_param_name.include?('=')
          # log("param name", optional_param_name, default_value, required_param_name)

          if optional_param_name
            { name: optional_param_name,
              optional: true,
              default: default_value }
          else
            # Probably required, but may be overriden latter via `@like other-feature`
            { name: probably_required_param_name }
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
        if block&.sub!(TYPES_PATTERN, '')
          types = $1.split(TYPES_SEPARATOR)
          types
        end
      end

      def postprocess!(documentable)
        if documentable.is_a?(Feature)
          merge_likes_in_signature!(documentable)
        end

        markdown = documentable.guide_markdown

        markdown = unescape_hash_headlines(markdown) if documentable.text_source.coffee_script?
        markdown = include_partials!(markdown)
        markdown = markdown.strip + "\n"

        documentable.guide_markdown = markdown
      end

      def merge_likes_in_signature!(feature)
        feature.params.each do |param|
          mimic_param!(param)
        end
        if (response = feature.response)
          mimic_response!(response)
        end
      end

      def mimic_param!(param)
        like_name = param.like_name

        if like_name
          other_feature_name, other_param_name = like_name.split('/')
          other_param_name ||= param.name

          other_feature = find_by_index_name!(other_feature_name)
          other_param = other_feature.find_param_by_name!(other_param_name)
          mimic_param!(other_param)
          param.mimic!(other_param)
        end
      end

      def mimic_response!(response)
        like_name = response.like_name

        if like_name
          other_feature = find_by_index_name!(like_name)
          # In the other feature, find a Param or Response with the same name.
          other_response = other_feature.response or raise Error, "Feature #{other_feature.name} has no response to mimic"
          mimic_response!(other_response)
          response.mimic!(other_response)
        end
      end

      def include_partials!(markdown)
        markdown.gsub(INCLUDE_PATTERN) do
          indent = $1
          name = $2
          indent_size = indent.gsub("\t", ' ').size

          partial = find_by_index_name!(name)

          text = partial.guide_markdown
          text.indent(indent_size)
        end
      end

      def unescape_hash_headlines(markdown)
        # We cannot use triple-hashes for h3 since
        # that would close CS block comments
        markdown.gsub /(\\#){2,}/ do |match|
          "#" * (match.size / 2)
        end
      end

      def looks_like_published_feature?(feature_name)
        feature_name =~ /^(x-)up[\.\:\-]/i
      end

      def cannot_parse!(doc_comment)
        raise CannotParse, "Doc comment is neither interface nor feature: #{doc_comment.path_with_lines}"
      end

    end

  end
end
