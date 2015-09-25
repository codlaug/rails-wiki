module Wiki
  class WikiController < ApplicationController

    before_action :set_a_bunch_of_shared_variables

    def root
      redirect_to '/' + clean_url(::File.join(@base_url, @page_dir, wiki_new.index_page))
    end


    def show_page_or_file
      wiki = wiki_new

      name = extract_name(request.path) || wiki.index_page
      path = '/' #extract_path(request.path) || '/'

      if page = wiki.paged(name, path, exact = true)
        @page          = page
        @name          = name
        @content       = page.formatted_data
        @upload_dest   = find_upload_dest(path)

        # Extensions and layout data
        @editable      = true
        @page_exists   = !page.versions.empty?
        @toc_content   = wiki.universal_toc ? @page.toc_data : nil
        @mathjax       = wiki.mathjax
        @h1_title      = wiki.h1_title
        @bar_side      = wiki.bar_side
        @allow_uploads = wiki.allow_uploads

        render :page
      elsif file = wiki.file(request.path, wiki.ref, true)
        show_file(file)
      else
        not_found unless @allow_editing
        page_path = [path, name].compact.join('/')
        redirect_to("/wiki/create/#{clean_url(encodeURIComponent(page_path))}")
      end
    end

    def fileview
      wiki     = wiki_new
      options  = settings.wiki_options
      content  = wiki.pages
      # if showing all files include wiki.files
      content  += wiki.files if options[:show_all]

      # must pass wiki_options to FileView
      # --show-all and --collapse-tree can be set.
      @results = Gollum::FileView.new(content, options).render_files
      @ref     = wiki.ref

      @title = "File view of #{@ref}"
      @has_results = !@results.empty?
      @no_results = @results.empty?
      
      render :file_view, { layout: false }
    end


    def new
      @is_create_page = true

      forbid unless @allow_editing
      wikip = wiki_page(params[:name].gsub('+', '-'))
      @name = wikip.name.to_url
      @path = wikip.path
      @allow_uploads = wikip.wiki.allow_uploads
      @upload_dest   = find_upload_dest(@path)

      page_dir = settings.wiki_options[:page_file_dir].to_s
      unless page_dir.empty?
        # --page-file-dir docs
        # /docs/Home should be created in /Home
        # not /docs/Home because write_page will append /docs
        @path = @path.sub(page_dir, '/') if @path.start_with? page_dir
      end
      @path = clean_path(@path)

      page = wikip.page
      if page
        page_dir = settings.wiki_options[:page_file_dir].to_s
        redirect to("/#{clean_url(::File.join(page_dir, page.escaped_url_path))}")
      else
        render :new
      end
    end


    def create
      name   = params[:page].to_url
      path   = sanitize_empty_params(params[:path]) || ''
      format = params[:format].intern
      wiki   = wiki_new

      path.gsub!(/^\//, '')

      begin
        wiki.write_page(name, format, params[:content], commit_message, path)

        page_dir = settings.wiki_options[:page_file_dir].to_s
        redirect_to("/#{clean_url(::File.join(page_dir, path, encodeURIComponent(name)))}")
      rescue Gollum::DuplicatePageError => e
        @message = "Duplicate page: #{e.message}"
        render :error
      end
    end

    def edit
      @is_edit_page = true

      forbid unless @allow_editing
      wikip = wiki_page(params[:name])
      @name = wikip.name
      @path = wikip.path
      @upload_dest   = find_upload_dest(@path)

      wiki = wikip.wiki
      @allow_uploads = wiki.allow_uploads
      if page = wikip.page
        if false && wiki.live_preview && page.format.to_s.include?('markdown') && supported_useragent?(request.user_agent)
          live_preview_url = '/wiki/livepreview/?page=' + encodeURIComponent(@name)
          if @path
            live_preview_url << '&path=' + encodeURIComponent(@path)
          end
          redirect_to(live_preview_url)
        else
          @page         = page
          @page.version = wiki.repo.log(wiki.ref, @page.path).first
          @content      = page.text_data
          render :edit
        end
      else
        redirect_to("/create/#{encodeURIComponent(@name)}")
      end
    end

    def update
      path      = '/' + clean_url(sanitize_empty_params(params[:path])).to_s
      page_name = CGI.unescape(params[:page])
      wiki      = wiki_new
      page      = wiki.paged(page_name, path, exact = true)
      return if page.nil?
      committer = Gollum::Committer.new(wiki, commit_message)
      commit    = { :committer => committer }

      update_wiki_page(wiki, page, params[:content], commit, page.name, params[:format])
      update_wiki_page(wiki, page.header, params[:header], commit) if params[:header]
      update_wiki_page(wiki, page.footer, params[:footer], commit) if params[:footer]
      update_wiki_page(wiki, page.sidebar, params[:sidebar], commit) if params[:sidebar]
      committer.commit

      redirect_to("/wiki/#{page.escaped_url_path}") unless page.nil?
    end


    def history
      @page     = wiki_page(params[:name]).page
      @page_num = [params[:page].to_i, 1].max
      unless @page.nil?
        @versions = @page.versions :page => @page_num
        render :history
      else
        redirect_to("/")
      end
    end


    # this should not be a post
    def comparePOST
      @file     = encodeURIComponent(params[:file])
      @versions = params[:versions] || []
      if @versions.size < 2
        redirect_to("/wiki/history/#{@file}")
      else
        redirect_to("/wiki/compare/%s/%s/%s" % [
            @file,
            @versions.last,
            @versions.first]
                 )
      end
    end

    def compare
      path = params[:path]
      start_version = params[:sha1]
      end_version = params[:sha2]
      wikip     = wiki_page(path)
      @path     = wikip.path
      @name     = wikip.name
      @versions = [start_version, end_version]
      wiki      = wikip.wiki
      @page     = wikip.page
      diffs     = wiki.repo.diff(@versions.first, @versions.last, @page.path)
      @diff     = diffs.first
      render :compare
    end




    private

    def update_wiki_page(wiki, page, content, commit, name = nil, format = nil)
      return if !page ||
          ((!content || page.raw_data == content) && page.format == format)
      name    ||= page.name
      format  = (format || page.format).to_sym
      content ||= page.raw_data
      wiki.update_page(page, name, format, content.to_s, commit)
    end

    # Detect unsupported browsers.
    Browser = Struct.new(:browser, :version)

    @@min_ua = [
        Browser.new('Internet Explorer', '10.0'),
        Browser.new('Chrome', '7.0'),
        Browser.new('Firefox', '4.0'),
    ]

    def supported_useragent?(user_agent)
      ua = UserAgent.parse(user_agent)
      @@min_ua.detect { |min| ua >= min }
    end

    # Options parameter to Gollum::Committer#initialize
    #     :message   - The String commit message.
    #     :name      - The String author full name.
    #     :email     - The String email address.
    # message is sourced from the incoming request parameters
    # author details are sourced from the session, to be populated by rack middleware ahead of us
    def commit_message
      msg               = (params[:message].nil? or params[:message].empty?) ? "[no message]" : params[:message]
      commit_message    = { :message => msg }
      author_parameters = session['gollum.author']
      commit_message.merge! author_parameters unless author_parameters.nil?
      commit_message
    end

    def sanitize_empty_params(param)
      [nil, ''].include?(param) ? nil : CGI.unescape(param)
    end

    # Extract the path string that Gollum::Wiki expects
    def extract_path(file_path)
      return nil if file_path.nil?
      last_slash = file_path.rindex("/")
      if last_slash
        file_path[0, last_slash]
      end
    end

    # Extract the 'page' name from the file_path
    def extract_name(file_path)
      if file_path[-1, 1] == "/"
        return nil
      end

      # File.basename is too eager to please and will return the last
      # component of the path even if it ends with a directory separator.
      ::File.basename(file_path)
    end

    def find_upload_dest(path)
      settings.wiki_options[:allow_uploads] ?
        (settings.wiki_options[:per_page_uploads] ?
          "#{path}/#{@name}".sub(/^\/\//, '') : 'uploads'
        ) : ''
    end

    # path is set to name if path is nil.
    #   if path is 'a/b' and a and b are dirs, then
    #   path must have a trailing slash 'a/b/' or
    #   extract_path will trim path to 'a'
    # name, path, version
    def wiki_page(name, path = nil, version = nil, exact = true)
      wiki = wiki_new
      path = name if path.nil?
      name = extract_name(name) || wiki.index_page
      path = extract_path(path)
      path = '/' if exact && path.nil?

      OpenStruct.new(:wiki => wiki, :page => wiki.paged(name, path, exact, version),
                     :name => name, :path => path)
    end

    def settings
      Precious::App.settings
    end

    # Ensure path begins with a single leading slash
    def clean_path(path)
      if path
        (path[0] != '/' ? path.insert(0, '/') : path).gsub(/\/{2,}/, '/')
      end
    end

    # Remove all slashes from the start of string.
    # Remove all double slashes
    def clean_url url
      return url if url.nil?
      url.gsub('%2F', '/').gsub(/^\/+/, '').gsub('//', '/')
    end


    def wiki_new
      Gollum::Wiki.new(settings.gollum_path, settings.wiki_options)
    end

    # this is a sinatra helper
    def url(addr = nil, absolute = true, add_script_name = true)
      return addr if addr =~ /\A[A-z][A-z0-9\+\.\-]*:/
      uri = [host = ""]
      if absolute
        host << "http#{'s' if request.secure?}://"
        if request.forwarded? or request.port != (request.secure? ? 443 : 80)
          host << request.host_with_port
        else
          host << request.host
        end
      end
      uri << request.script_name.to_s if add_script_name
      uri << (addr ? addr : request.path_info).to_s
      File.join uri
    end


    def set_a_bunch_of_shared_variables
      settings.wiki_options[:allow_editing] = settings.wiki_options.fetch(:allow_editing, true)
      @allow_editing = settings.wiki_options[:allow_editing]
      forbid unless @allow_editing || request.request_method == "GET"
      Precious::App.set(:mustache, {:templates => settings.wiki_options[:template_dir]}) if settings.wiki_options[:template_dir]
      @base_url = url('/', false).chomp('/')
      @page_dir = settings.wiki_options[:page_file_dir].to_s
      # above will detect base_path when it's used with map in a config.ru
      settings.wiki_options.merge!({ :base_path => @base_url })
      @css = settings.wiki_options[:css]
      @js  = settings.wiki_options[:js]
      @mathjax_config = settings.wiki_options[:mathjax_config]
    end

  end
end