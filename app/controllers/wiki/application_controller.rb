module Wiki
  class ApplicationController < ActionController::Base

    before_filter :allow_editing
    # helper_method :allow_editing

    def allow_editing
      settings = Precious::App.settings
      settings.wiki_options[:allow_editing] = settings.wiki_options.fetch(:allow_editing, true)
      @allow_editing = settings.wiki_options[:allow_editing]
      forbid unless @allow_editing || request.request_method == "GET"
    end

  end
end
