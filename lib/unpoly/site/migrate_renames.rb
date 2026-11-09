module Unpoly
  module Site
    # Old API names and their successors, as unpoly-migrate records them. bin/not-found-stats
    # sends old names to their successor's page, ParamRedirects sends renamed attributes to
    # their successor's section. Loads without the rest of the site, like NotFoundStats.
    module MigrateRenames

      # up.render, up:layer:open, up-follow, X-Up-Target
      API_NAME = /\A(up[.:-]|x-up-)/i

      module_function

      # Old names and their successors, from the calls in unpoly-migrate:
      #
      #     renamedNamespace('layout', 'viewport')
      #     renamedEvent('up:modal:open', 'up:layer:open')
      #     renamedAttribute('up-flavor', 'up-mode', { scope: ... })
      #     renamedProperty(config, 'fields', 'fieldSelectors', { label: 'up.form.config' })
      #     deprecated('up.util.any()', 'up.util.some()')
      #
      # A renamed namespace also renames everything in it (up.layout.revealHash). An old
      # namespace without a rename of its own (up.modal) goes where most of its recorded
      # members went (up.layer). An old name with several successors keeps the first, by
      # file name. Returns [renamed namespaces, successors].
      def read(dir)
        namespaces = {}
        successors = {}
        Dir.glob(File.join(dir, '**/*.{js,ts}')).sort.each do |file|
          File.foreach(file) do |line|
            call = line.match(/up\.migrate\.(renamed\w+|deprecated)\((.*)\)/) or next
            function, args = call.captures
            old, new = args.scan(/'([^']*)'|"([^"]*)"|`([^`]*)`/).flatten.compact
            case function
            when 'renamedNamespace'
              old, new = "up.#{old}", "up.#{new}"
              namespaces[old] = new
            when 'renamedProperty'
              owner = args[/\A(up\.[\w.]+)/, 1] || args[/label: '([^']+)'/, 1] or next
              old, new = "#{owner}.#{old}", "#{owner}.#{new}"
            else
              old, new = api_name(old), api_name(new)
            end
            successors[old] ||= new if old&.match?(API_NAME) && new
          end
        end
        successors.keys.group_by { |old| old[/\Aup\.\w+(?=\.)/] }.each do |namespace, members|
          new, count = members.map { |member| successors[member][/\A[^.]+\.[^.]+/] }.tally.max_by(&:last)
          successors[namespace] ||= new if namespace && new != namespace && count > members.size / 2
        end
        [namespaces, successors]
      end

      # 'up.util.pick(object, keys)' => 'up.util.pick'. 'up.Request#loadPage()' =>
      # 'up.Request.prototype.loadPage'. nil for prose like "a `for` loop".
      def api_name(code)
        code&.delete_prefix('!')&.[](/\A[\w.:#-]+(?=\(|\s*=|\s*\{|\z)/)&.sub('#', '.prototype.')
      end

    end
  end
end
