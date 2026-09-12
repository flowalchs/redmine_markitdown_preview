# frozen_string_literal: true

require 'redmine_plugin_kit'

module RedmineMarkitdownPreview
  VERSION = '1.0.0'

  include RedminePluginKit::PluginBase

  class << self
    def safe_setting(key)
      setting(key.to_sym)
    end

    def safe_setting_array(name)
      safe_setting(name).to_s.split(/[\s,;]+/).reject(&:blank?)
    end

    def preview_storage_path
      File.join(Attachment.storage_path, 'derived_cache',  'markitdown_previews')
    end

    private

    def setup
      loader.add_patch %w[Attachment
                          AttachmentsController
                          SettingsController]

      loader.apply!
      loader.load_view_hooks!
    end
  end
end
