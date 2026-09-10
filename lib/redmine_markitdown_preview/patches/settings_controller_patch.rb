# frozen_string_literal: true

module RedmineMarkitdownPreview
  module Patches
    module SettingsControllerPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        def plugin
          super

          return unless request.post?
          return unless params[:id] == 'redmine_markitdown_preview'

          RedmineMarkitdownPreview::Converter.reset_settings_cache!
        end
      end
    end
  end
end
