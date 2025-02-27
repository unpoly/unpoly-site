module Unpoly
  module Guide
    class Parser
      include Logger
      include Memoized

      class Error < StandardError; end
      class CannotParse < Error; end
      class MissingVisibility < CannotParse; end

      # Must be a string because we contain a backreference to a capture
      # group that will only exist later (\1)
      INDENTED_BODY_PATTERN = '
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
      '

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
        ([^\ \t\n]+)    # index_name of referenced documentable ($1)
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
        (                           # visibility comment, mostly for deprecation ($3)
          .*$                       # .. remainder of first line
          #{INDENTED_BODY_PATTERN}  # subsequent lines that are indented further than the first line
        )
      }x

      # ESSENTIAL_PATTERN = %r{
      #   (^[ \t]*)        # first line indent ($1)
      #   \@(              # essential tag ($2)
      #     essential
      #   )
      # }x

      PARAMS_NOTE_PATTERN = %r{
        (^[ \t]*)                   # first line indent ($1)
        \@(params-note)             # tag ($2)
        (                           # note markdown ($3)
          .*$                       # .. remainder of first line
          #{INDENTED_BODY_PATTERN}  # subsequent lines that are indented further than the first line
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
        (                           # response spec ($4)
          .*$                       # .. remainder of first line
          #{INDENTED_BODY_PATTERN}  # subsequent lines that are indented further than the first line
        )
      }x

      PARAM_SECTION_PATTERN = %r{
        (^[ \t]*)                  # first line indent ($1)
        @section                   # @section
        \s+                        # whitespace
        (.+?)                      # title ($2)
        $                          # end of line
        (#{INDENTED_BODY_PATTERN}) # indented body ($3)
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
          #{INDENTED_BODY_PATTERN}  # subsequent lines that are indented further than the first line
        )
      }x

      MIX_PARAMS_PATTERN = %r{
        (^[ \t]*)                  # first line indent ($1)
        @mix                       # @nix
        [ \t]+                     # whitespace
        (.+?)                      # documentable name ($2)
        $                          # end of line
        (#{INDENTED_BODY_PATTERN}) # indented body ($3)
      }x

      PARAM_SOURCE_PATTERN = %r{
        (^[ \t]*)                      # first line indent ($1)
        (@param|@section|@mix)         # @directive ($2), but not @params-note
        [ \t]+                         # whitespace after directive
        (                              # full spec ($3)
          (.+$)                        # .. remainder of first line after @directive ($4)
          (#{INDENTED_BODY_PATTERN})   # indented body ($5)
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
        ([^\ \t\n]+)      # required param name ($3), possibly followed by a description on the same line
      }x

      REFERENCE_PATTERN = %r{
        \@see
        \s+
        (.+?) # guide ID ($1)
        (\n|$)
      }x

      def initialize(repository)
        @repository = repository
        @last_interface = nil

        @documentables_by_index_name = {}
      end

      def parse_all(paths)
        doc_comments = paths.flat_map { |path| DocComment.find_in_path(path) }

        # First, parse all the partials so other documentables can @include partials
        # before further parsing.
        doc_comments.each do |doc_comment|
          partials = parse_partial(doc_comment) || []
          partials.each do |partial|
            partial.text_source = doc_comment.text_source
            index_documentable(partial)
          end
        end

        doc_comments.each do |doc_comment|
          doc_comment.text = including_partials(doc_comment.text)

          documentables_from_comment = parse_interface(doc_comment) || parse_feature(doc_comment) || parse_partial(doc_comment) || cannot_parse!(doc_comment)
          documentables_from_comment.each do |documentable|
            documentable.text_source = doc_comment.text_source
            index_documentable(documentable)
          end
        end

        documentables.each do |documentable|
          postprocess!(documentable)
        end
      end

      private

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

      def parse_partial(doc_comment)
        text = doc_comment.text.dup

        if text.sub!(PARTIAL_PATTERN, '')
          partial_name = $1.strip

          partial = Partial.new(partial_name)
          text = Util.unindent(text)
          text = text.strip + "\n"
          partial.guide_markdown = text

          [partial]
        end
      end

      def parse_interface(doc_comment)
        block = doc_comment.text.dup

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

      def parse_feature(doc_comment)
        text = doc_comment.text.dup

        if text.sub!(FEATURE_PATTERN, '')
          feature_kind = $1.strip
          feature_name = $2.strip
          text = Util.unindent(text)

          feature = Feature.new(feature_kind, feature_name)

          new_params = parse_param_sources!(text)
          new_params.each do |new_param|
            new_param.feature = feature
            feature.params << new_param
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

      def parse_section_params!(block)
        if block.sub!(PARAM_SECTION_PATTERN, '')
          title = $2
          body = $3

          params = parse_param_sources!(body)
          params.each do |param|
            param.section_title = title
          end

          params
        end
      end

      def parse_param_literals!(block)
        params = []

        while block.sub!(PARAM_PATTERN, '')
          type_spec = $2
          param_spec = $4
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

          # Params can either be described in the signature line
          # or in the indented body below it.
          markdown = Util.unindent_hanging(param_spec)

          parse_references!(markdown, param)

          param.guide_markdown = markdown
          params << param
        end

        params
      end

      def parse_param_sources!(text)
        all_params = []

        while text.sub!(PARAM_SOURCE_PATTERN, '')
          directive = $2
          full_match = $& + "\n"

          source_params = case directive
          when '@section'
            parse_section_params!(full_match)
          when '@param'
            parse_param_literals!(full_match)
          when '@mix'
            parse_mixed_params!(full_match)
          else
            raise CannotParse, "Unknown directive: #{directive}"
          end

          all_params.concat(source_params)
        end

        all_params
      end

      def parse_mixed_params!(block)
        if block.sub!(MIX_PARAMS_PATTERN, '')
          documentable_name = $2
          override_spec = $3

          documentable = find_by_index_name!(documentable_name)
          documentable_source = including_partials(documentable.text_source.text.dup)

          documentable_params = parse_param_literals!(documentable_source)
          override_params = parse_param_literals!(override_spec)

          mixed_params = documentable_params.map { |documentable_param|
            override_index = override_params.index { |override_param| override_param.name == documentable_param.name }
            if override_index
              # Remember which params found their override parent, so we can raise if something didn't match.
              override_param = override_params.delete_at(override_index)
              # Allow to override some properties, while inheriting the reset
              override_param.mimic!(documentable_param)
              override_param
            else
              documentable_param
            end
          }

          unless override_params.empty?
            raise Error, "Tried to override params from #{documentable_name}, but could not find param #{override_params.first.name}"
          end

          mixed_params
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
          mimic_likes_in_signature!(documentable)
        end

        markdown = documentable.guide_markdown
        markdown = unescape_hash_headlines(markdown) if documentable.text_source.coffee_script?
        markdown = markdown.strip + "\n"
        documentable.guide_markdown = markdown
      end

      def mimic_likes_in_signature!(feature)
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

      def including_partials(markdown)
        markdown.gsub(INCLUDE_PATTERN) do
          indent = $1
          name = $2
          indent_size = indent.gsub("\t", '  ').size

          partial = find_by_index_name!(name)

          text = partial.guide_markdown
          text = including_partials(text)
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
        raise CannotParse, "Doc comment with unknown @type: #{doc_comment.path_with_lines}"
      end

    end

  end
end
