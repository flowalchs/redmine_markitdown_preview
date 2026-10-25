# frozen_string_literal: true

require 'yaml'

module RedmineMarkitdownPreview
  VERSION = '1.0.2'
  PLUGIN_ID = 'redmine_markitdown_preview'

  class << self
    def setup!
      apply_patch Attachment, Patches::AttachmentPatch
      apply_patch AttachmentsController, Patches::AttachmentsControllerPatch
      apply_patch SettingsController, Patches::SettingsControllerPatch
    end

    def default_settings
      @default_settings ||= begin
        file = File.expand_path('../config/settings.yml', __dir__)
        (YAML.safe_load(File.read(file)) || {}).with_indifferent_access
      end
    end

    def settings
      (Setting[:"plugin_#{PLUGIN_ID}"] || {}).with_indifferent_access
    end

    # stored setting with default setting as fall back
    def safe_setting(key)
      current = settings
      current.key?(key) ? current[key] : default_settings[key]
    end

    def safe_setting_array(name)
      safe_setting(name).to_s.split(/[\s,;]+/).reject(&:blank?)
    end

    def preview_storage_path
      File.join(Attachment.storage_path, 'derived_cache',  'markitdown_previews')
    end

    private

    def apply_patch(target, patch)
      target.include patch unless target.included_modules.include?(patch)
    end
  end
end
