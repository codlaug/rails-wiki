module Wiki
  class Engine < ::Rails::Engine
    isolate_namespace Wiki

    initializer "wiki.assets.precompile" do |app|
      app.config.assets.precompile += %w(wiki/_styles.css wiki/livepreview/livepreview.js wiki/livepreview.css)
    end
  end
end
