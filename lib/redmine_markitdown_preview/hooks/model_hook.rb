# frozen_string_literal: true

module RedmineMarkitdownPreview
  module Hooks
    class ModelHook < Redmine::Hook::Listener
      def after_plugins_loaded(_context = {})
        RedmineMarkitdownPreview.setup!
      end
    end
  end
end