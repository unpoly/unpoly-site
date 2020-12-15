module Unpoly
  module Guide
    module TypeScript
      class CannotRender < Error; end

      # https://www.typescriptlang.org/docs/handbook/declaration-files/templates/global-d-ts.html
      class Renderer

        def initialize
          @out = ''
        end

        attr_reader :out

        def render_repository(repository)
          repository.interfaces.each do |interface|
            render_interface(interface)
          end
        end

        def render_interface(interface)
          if interface.kind == 'class'
            render_class(interface)
          else
            render_module(interface)
          end
        end

        def render_class(klass)
          # todo
        end

        def render_module(mod)
          published_features(mod).each do |feature|
            case feature.kind
            when 'function'
              render_module_function(mod, feature)
            when 'property'
              render_module_property(mod, feature)
            when 'event'  
              render_module_event(mod, feature)
            else
              cannot_render(feature)  
            end
          end
        end

        def render_module_function(mod, function) 
          parts = function.name.split('.')[0..-1]
          namespace*, unqualified_name = parts

          render_namespace(namespace) do
            text "function #{unqualified_name}("
              render_param_groups(function.param_groups)
            text ")"
            newline
          end
        end

        def render_param_groups(groups)
          groups.each_with_index do |group, i|
            text ', ' if i > 0
            
            if group.is_a?(OptionsParams)
              text "{ "
              group.properties.each_with_index do |property, index|
                text ", " if index > 0
                render_simple_param(property)
              end
              text " }"
            else
              render_simple_param(group)
            end
          end
        end

        def render_simple_param(param)
          text "#{property.name_without_option_prefix}"
          
          if property.optional?
            text '?'
          end
          
          text ': '
          render_type(property.types)
        end

        def render_module_property(mod, property)
          # TODO
        end
        
        def render_module_event(mod, event)
          # TODO
        end

        def render_namespace(namespace, &block)
          head, *tail = namespace

          if head
            block "declare namespace #{head}" do
              render_namespace(tail)
            end
          else
            block.call
          end  
        end

        private

        def render_type(types)
          types = Array.wrap(types)
          if type.blank?
            text 'any'
          else
            text types.join('|')
          end  
        end

        def block(string, &inner)
          line "#{string} {"
            inner.call
          line "}"  
        end

        def text(string)
          out << string
        end

        def line(string = "")
          text(string)
          newline
        end

        def newline
          text "\n"
        end

        def published_features(parent)
          parent.features.reject { |feature|
            feature.internal? || feature.selector? || feature.header? || feature.cookie?
          }
        end

        def cannot_render(thing)
          throw CannotRender, "Don't know how to render #{thing.class.name}"
        end  

      end
    end
  end
end
