module Unpoly
  module Site
    # Redirects /up-target and /api/up-target to /api/up-follow#up-target.
    #
    # People and agents see an attribute like [up-target] in code and guess a URL for it.
    # But an attribute that only modifies another one has no page of its own: it is a
    # section on the page of the attribute it modifies. So every attribute param of a
    # published selector redirects to its section, and so does the old name of a renamed
    # attribute (up-flavor to up-mode). Function options and JavaScript params are left
    # out: nobody guesses /up.render/target.
    #
    # A name that a hand-written redirect already starts at gets no rule of ours. Neither
    # does a name that is also a page's slug (/up-transition): the short-path rule in
    # source/.htaccess.erb takes that path first, so a redirect would never fire (UrlCheck
    # fails on one).
    class ParamRedirects

      # A param that several attributes take (up-target on [up-follow], [up-submit],
      # [up-layer=new] and [up-defer]) goes to the first of these that has it: they
      # document their params in full, the others mostly refer to them. If none of them
      # has it, the param goes to the alphabetically first attribute, so the target never
      # changes between builds. The build lists those names (#unprioritized), as
      # candidates for this list.
      PRIORITY = %w[up-follow up-submit up-watch].freeze

      def initialize(repository = Site.current, url_check: UrlCheck.new(repository))
        @repository = repository
        @url_check = url_check
      end

      # { 'up-target' => '/api/up-follow#up-target' }, renamed attributes included.
      def targets
        @targets ||= begin
          targets = params_by_name.transform_values { |params| winner(params).guide_path }
          MigrateRenames.read(File.join(@repository.path, 'src', 'unpoly-migrate')).last.each do |old, new|
            # Only attributes are named like this: events have colons, functions dots.
            next unless old.start_with?('up-') && targets[new] && !params_by_name.key?(old) && free?(old)
            targets[old] = targets[new]
          end
          targets
        end
      end

      # Every path a rule redirects, for UrlCheck: { '/up-target' => target, '/api/up-target' => target }.
      def paths
        targets.each_with_object({}) do |(name, target), paths|
          paths["/#{name}"] = target
          paths["#{API_PATH}/#{name}"] = target
        end
      end

      # One rule per name for both of its paths.
      def htaccess
        targets.map { |name, target| "RedirectMatch permanent ^/(api/)?#{Regexp.escape(name)}$ #{target}" }.join("\n")
      end

      # Names that the attributes in PRIORITY don't take, but several others do, each with
      # these attributes: { 'up-if-layer' => ['[up-hungry]', '[up-poll]'] }.
      def unprioritized
        params_by_name.select { |_, params| params.size > 1 && params.none? { |param| prioritized?(param) } }
          .transform_values { |params| params.map { |param| param.feature.name }.sort }
      end

      private

      def params_by_name
        @params_by_name ||= @repository.features
          .select { |feature| feature.selector? && feature.published? && !feature.fixture? }
          .flat_map(&:published_params)
          # Leaves out the plain HTML attributes some selectors document (href, method).
          .select { |param| param.name.start_with?('up-') && free?(param.name) }
          .group_by(&:name)
      end

      def winner(params)
        params.min_by { |param| [PRIORITY.index(attribute(param.feature)) || PRIORITY.size, param.feature.name] }
      end

      def prioritized?(param)
        PRIORITY.include?(attribute(param.feature))
      end

      # '[up-follow]' => 'up-follow', '[up-layer=new]' => 'up-layer'
      def attribute(feature)
        feature.name[/\[([\w-]+)/, 1]
      end

      # Neither a page's slug nor the start of a hand-written redirect.
      def free?(name)
        path = "/#{name}"
        !@url_check.current_paths.include?(path) && !@url_check.short_path_target(path) &&
          !@url_check.hand_written_redirects.key?(path)
      end

    end
  end
end
