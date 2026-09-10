# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class SettingsControllerTest < MarkitdownPreview::Test::ControllerCase
  tests SettingsController

  def setup
    super
    set_session_user(@admin)
  end

  def test_should_show_default_settings
    get :plugin,
        params: {
          id: 'redmine_markitdown_preview'
        }

    assert_response :success

    assert_select(
      'input[name="settings[markitdown_preview_generation_timeout]"][value="10"]'
    )

    assert_select(
      'input[name="settings[markitdown_preview_max_source_size]"][value="10485760"]'
    )

    assert_select(
      'input[name="settings[markitdown_preview_max_output_size]"][value="102400"]'
    )

    assert_select(
      'input[name="settings[markitdown_supported_extensions]"]'
    )
  end

  def test_plugin_settings_reset_converter_cache
    with_markitdown_settings(
      markitdown_supported_extensions: '.xls'
    ) do
      converter = RedmineMarkitdownPreview::Converter

      assert_equal(
        ['.xls'],
        converter.send(:supported_extensions)
      )

      post(
        :plugin,
        params: {
          id: 'redmine_markitdown_preview',
          settings: {
            markitdown_supported_extensions: '.docx'
          }
        }
      )

      assert_response :redirect

      assert_equal(
        ['.docx'],
        converter.send(:supported_extensions)
      )
    end
  end

  def test_settings_change_reload_converter_cache
    with_markitdown_settings(
      markitdown_supported_extensions: '.xls'
    ) do
      assert_equal(
        ['.xls'],
        RedmineMarkitdownPreview::Converter.send(
          :supported_extensions
        )
      )

      Setting.plugin_redmine_markitdown_preview =
        Setting.plugin_redmine_markitdown_preview.merge(
          markitdown_supported_extensions: '.docx'
        )

      RedmineMarkitdownPreview::Converter.reset_settings_cache!

      assert_equal(
        ['.docx'],
        RedmineMarkitdownPreview::Converter.send(
          :supported_extensions
        )
      )
    end
  end

  def test_preview_generation_timeout_uses_default_for_negative_value
    with_markitdown_settings(
      markitdown_preview_generation_timeout: -5
    ) do
      RedmineMarkitdownPreview::Converter.reset_settings_cache!

      assert_equal(
        10,
        RedmineMarkitdownPreview::Converter.send(
          :preview_generation_timeout
        )
      )
    end
  end

  def test_maximum_output_size_uses_default_for_negative_value
    with_markitdown_settings(
      markitdown_preview_max_output_size: -100
    ) do
      RedmineMarkitdownPreview::Converter.reset_settings_cache!

      assert_equal(
        100.kilobytes,
        RedmineMarkitdownPreview::Converter.send(
          :maximum_output_size
        )
      )
    end
  end

  def test_negative_max_source_size_disables_limit
    with_markitdown_settings(
      markitdown_preview_max_source_size: -1
    ) do
      assert_not(
        RedmineMarkitdownPreview::Converter.send(
          :source_too_large?,
          1_000_000
        )
      )
    end
  end
end
