module Wiki
  module WikiHelper

    DATE_FORMAT    = "%Y-%m-%d %H:%M:%S"
    DEFAULT_AUTHOR = 'you'

    def default_markup
      Precious::App.settings.default_markup
    end

    def is_create_page
      @is_create_page || false
    end

    def is_edit_page
      @is_edit_page || false
    end

    def allow_uploads
      @allow_uploads
    end

    def page_name
      @name.gsub('-', ' ')
    end

    def has_header
      if @header
        @header.formatted_data.strip.empty? ? false : true
      else
        @header = (@page.header || false)
        !!@header
      end
    end

    def has_footer
      if @footer
        @footer.formatted_data.strip.empty? ? false : true
      else
        @footer = (@page.footer || false)
        !!@footer
      end
    end

    def has_sidebar
      if @sidebar
        @sidebar.formatted_data.strip.empty? ? false : true
      else
        @sidebar = (@page.sidebar || false)
        !!@sidebar
      end
    end

    def author
      page_versions = @page.versions
      first         = page_versions ? page_versions.first : false
      return DEFAULT_AUTHOR unless first
      first.author.name.respond_to?(:force_encoding) ? first.author.name.force_encoding('UTF-8') : first.author.name
    end

    def date
      page_versions = @page.versions
      first         = page_versions ? page_versions.first : false
      return Time.now.strftime(DATE_FORMAT) unless first
      first.authored_date.strftime(DATE_FORMAT)
    end

    def has_toc
      !@toc_content.nil?
    end

    def path
      @path
    end

    def escaped_url_path
      @page.escaped_url_path
    end

    def title
      h1 = @h1_title ? page_header_from_content(@content) : false
      h1 || @page.url_path_title
    end

    def page_header
      title
    end

    def allow_editing
      @allow_editing
    end

    def editable
      @editable
    end

    def page_exists
      @page_exists
    end

    def format
      @format = (@page.format || false) if @format.nil? && @page
      @format.to_s.downcase
    end

    def formats(selected = @page.format)
      Gollum::Markup.formats.map do |key, val|
        { :name     => val[:name],
          :id       => key.to_s,
          :selected => selected == key }
      end.sort do |a, b|
        a[:name].downcase <=> b[:name].downcase
      end
    end

    def header
      @header
    end

    def footer
      @footer
    end

    def sidebar
      @sidebar
    end

    def content
      @content
    end

  end
end