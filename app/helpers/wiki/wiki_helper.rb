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

    def show_revert
      !@message
    end

    def page_name
      @name.gsub('-', ' ')
    end

    def versions
      i = @versions.size + 1
      @versions.map do |v|
        i -= 1
        { :id        => v.id,
          :id7       => v.id[0..6],
          :num       => i,
          :selected  => @page.version.id == v.id,
          :author    => v.author.name.respond_to?(:force_encoding) ? v.author.name.force_encoding('UTF-8') : v.author.name,
          :message   => v.message.respond_to?(:force_encoding) ? v.message.force_encoding('UTF-8') : v.message,
          :date      => v.authored_date.strftime("%B %d, %Y"),
          :gravatar  => Digest::MD5.hexdigest(v.author.email.strip.downcase),
          :identicon => self._identicon_code(v.author.email),
          :date_full => v.authored_date,
        }
      end
    end

    def lines
      lines = []
      @diff.diff.split("\n")[2..-1].each_with_index do |line, line_index|
        lines << { :line  => line,
                   :class => line_class(line),
                   :ldln  => left_diff_line_number(0, line),
                   :rdln  => right_diff_line_number(0, line) }
      end if @diff
      lines
    end

    def line_class(line)
      if line =~ /^@@/
        'gc'
      elsif line =~ /^\+/
        'gi'
      elsif line =~ /^\-/
        'gd'
      else
        ''
      end
    end

    @left_diff_line_number = nil

    def left_diff_line_number(id, line)
      if line =~ /^@@/
        m, li                  = *line.match(/\-(\d+)/)
        @left_diff_line_number = li.to_i
        @current_line_number   = @left_diff_line_number
        ret                    = '...'
      elsif line[0] == ?-
        ret                    = @left_diff_line_number.to_s
        @left_diff_line_number += 1
        @current_line_number   = @left_diff_line_number - 1
      elsif line[0] == ?+
        ret = ' '
      else
        ret                    = @left_diff_line_number.to_s
        @left_diff_line_number += 1
        @current_line_number   = @left_diff_line_number - 1
      end
      ret
    end

    @right_diff_line_number = nil

    def right_diff_line_number(id, line)
      if line =~ /^@@/
        m, ri                   = *line.match(/\+(\d+)/)
        @right_diff_line_number = ri.to_i
        @current_line_number    = @right_diff_line_number
        ret                     = '...'
      elsif line[0] == ?-
        ret = ' '
      elsif line[0] == ?+
        ret                     = @right_diff_line_number.to_s
        @right_diff_line_number += 1
        @current_line_number    = @right_diff_line_number - 1
      else
        ret                     = @right_diff_line_number.to_s
        @right_diff_line_number += 1
        @current_line_number    = @right_diff_line_number - 1
      end
      ret
    end

    def before
      @versions[0][0..6]
    end

    def after
      @versions[1][0..6]
    end

    ####

    def _identicon_code(blob)
      string_to_code blob + request.host
    end


    def string_to_code string
      # sha bytes
      b = [Digest::SHA1.hexdigest(string)[0, 20]].pack('H*').bytes.to_a
      # Thanks donpark's IdenticonUtil.java for this.
      # Match the following Java code
      # ((b[0] & 0xFF) << 24) | ((b[1] & 0xFF) << 16) |
      #  ((b[2] & 0xFF) << 8) | (b[3] & 0xFF)

      return left_shift(b[0], 24) |
          left_shift(b[1], 16) |
          left_shift(b[2], 8) |
          b[3] & 0xFF
    end

    # http://stackoverflow.com/questions/9445760/bit-shifting-in-ruby
    def left_shift int, shift
      r = ((int & 0xFF) << (shift & 0x1F)) & 0xFFFFFFFF
      # 1>>31, 2**32
      (r & 2147483648) == 0 ? r : r - 4294967296
    end

    ######

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