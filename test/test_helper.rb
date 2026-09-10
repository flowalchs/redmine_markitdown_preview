# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  require 'simplecov-cobertura'

  SimpleCov.coverage_dir 'coverage'

  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::CoberturaFormatter
  ]

  SimpleCov.start :rails do
    add_filter 'init.rb'
    root File.expand_path("#{File.dirname __FILE__}/..")
  end

  # Cobertura-XML at the end
  at_exit do
    result = SimpleCov.result
    # Cobertura-file
    SimpleCov::Formatter::CoberturaFormatter.new.format(result)
    # html also
    SimpleCov::Formatter::HTMLFormatter.new.format(result)
  end
end

$VERBOSE = nil if ENV['SUPPRESS_WARNINGS']

# Load the normal Rails helper
require File.expand_path('../../../test/test_helper', __dir__)

PLUGIN_FIXTURES_DIR = File.expand_path('fixtures', __dir__)

module MarkitdownPreview
  module Test
    module PluginTestSetting
      def load_plugin_fixtures_in_order!
        ActiveRecord::FixtureSet.reset_cache
        set_tmp_attachments_directory
      end

      def load_default_values!
        @admin = User.find_by(login: 'admin')
        @jsmith = User.find_by(login: 'jsmith')
        @dlopper = User.find_by(login: 'dlopper')
        @rhill = User.find_by(login: 'rhill')
      end

      def set_session_user(user)
        @user = user
        @request.session[:user_id] = @user.id
        User.current = @user
      end

      def teardown_method!
        User.current = nil
        Setting.clear_cache
        Rails.cache.clear
        I18n.locale = :en

        clear_markitdown_preview_cache
        RedmineMarkitdownPreview::Converter.reset_settings_cache!
      end

      def plugin_fixture_file(filename)
        File.join(PLUGIN_FIXTURES_DIR, 'files', filename)
      end

      def uploaded_plugin_test_file(filename, content_type)
        Rack::Test::UploadedFile.new(plugin_fixture_file(filename), content_type, true, original_filename: filename)
      end

      def clear_markitdown_preview_cache
        FileUtils.rm_rf(RedmineMarkitdownPreview.preview_storage_path)
      end

      def create_attachment(filename, content_type)
        attachment = Attachment.new(
          container: Issue.find(1),
          file: uploaded_plugin_test_file(filename, content_type),
          author: User.find(1)
        )

        assert attachment.save,
               attachment.errors.full_messages.join(', ')

        attachment
      end

      def with_markitdown_settings(updates)
        current = Setting.plugin_redmine_markitdown_preview.deep_dup
        Setting.plugin_redmine_markitdown_preview = current.merge(updates)
        Setting.clear_cache
        RedmineMarkitdownPreview::Converter.reset_settings_cache!

        yield
      ensure
        Setting.plugin_redmine_markitdown_preview = current

        Setting.clear_cache
        RedmineMarkitdownPreview::Converter.reset_settings_cache!
      end
    end

    class UnitCase < ActiveSupport::TestCase
      self.use_transactional_tests = true
      fixtures :all

      include MarkitdownPreview::Test::PluginTestSetting

      def setup
        load_plugin_fixtures_in_order!
        load_default_values!

        set_tmp_attachments_directory
        clear_markitdown_preview_cache
        RedmineMarkitdownPreview::Converter.reset_settings_cache!
      end

      def teardown
        super
        teardown_method!
      end
    end

    class ControllerCase < Redmine::ControllerTest
      self.use_transactional_tests = true
      fixtures :all

      include MarkitdownPreview::Test::PluginTestSetting

      def setup
        load_plugin_fixtures_in_order!
        load_default_values!
      end

      def teardown
        super
        teardown_method!
      end
    end
  end
end
