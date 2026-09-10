# frozen_string_literal: true

loader = RedminePluginKit::Loader.new plugin_id: 'redmine_markitdown_preview'

Redmine::Plugin.register :redmine_markitdown_preview do
  name 'Redmine MarkItDown Preview'
  author 'Florian Walchshofer'
  author_url 'https://github.com/flowalchs/'
  description 'Adds attachment previews using Microsoft MarkItDown for Office documents, Outlook messages and other supported formats'
  url 'https://github.com/flowalchs/redmine_markitdown_preview/'
  version RedmineMarkitdownPreview::VERSION
  requires_redmine :version_or_higher => '4.0.0'

  settings default: loader.default_settings,
           partial: 'settings/markitdown'
end

RedminePluginKit::Loader.persisting do
  # Hooks
  loader.load_model_hooks!
end
