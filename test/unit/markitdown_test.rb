require File.expand_path('../test_helper', __dir__)

class MarkitdownTest < MarkitdownPreview::Test::UnitCase
  def setup
    super
    User.current = nil
  end

  def test_convert_returns_cached_preview
    source = plugin_fixture_file('mail_sample.msg')

    Dir.mktmpdir do |dir|
      target = File.join(dir, 'preview.md')

      File.write(target, 'cached')

      assert_equal(
        target,
        RedmineMarkitdownPreview::Converter.convert(
          source,
          target
        )
      )

      assert_equal 'cached', File.read(target)
    end
  end

  def test_convert_returns_nil_when_source_file_missing
    Dir.mktmpdir do |dir|
      target = File.join(dir, 'preview.md')

      assert_nil(
        RedmineMarkitdownPreview::Converter.convert(
          '/tmp/does-not-exist.docx',
          target
        )
      )
    end
  end

  def test_convert_returns_nil_when_converter_not_available
    RedmineMarkitdownPreview::Converter
      .stubs(:available?)
      .returns(false)

    source = plugin_fixture_file('mail_sample.msg')

    Dir.mktmpdir do |dir|
      target = File.join(dir, 'preview.md')

      assert_nil(
        RedmineMarkitdownPreview::Converter.convert(
          source,
          target
        )
      )
    end
  end

  def test_convert_returns_nil_when_command_fails
    source = plugin_fixture_file('mail_sample.msg')

    status = mock
    status.stubs(:success?).returns(false)
    status.stubs(:exitstatus).returns(1)

    Process.stubs(:spawn).returns(1234)
    Process.stubs(:wait2).returns([1234, status])

    Dir.mktmpdir do |dir|
      target = File.join(dir, 'preview.md')

      assert_nil(
        RedmineMarkitdownPreview::Converter.convert(
          source,
          target
        )
      )
    end
  end

  def test_convert_returns_nil_on_exception
    converter = RedmineMarkitdownPreview::Converter

    converter.stubs(:available?).returns(true)

    Process
      .stubs(:spawn)
      .raises(StandardError.new('boom'))

    source = plugin_fixture_file('mail_sample.msg')

    Dir.mktmpdir do |dir|
      target = File.join(dir, 'preview.md')

      assert_nil converter.convert(source, target)
      assert_not File.exist?(target)
    end
  end

  def test_markitdown_preview_content_logs_error_and_returns_nil
    attachment = create_attachment(
      'sample_old.xls',
      'application/vnd.ms-excel'
    )

    attachment.stubs(:markitdown_previewable?).returns(true)

    RedmineMarkitdownPreview::Converter
      .stubs(:convert)
      .raises(StandardError.new('boom'))

    Rails.logger.expects(:error).with do |message|
      message.include?('An error occurred while generating MarkItDown preview') &&
        message.include?('boom')
    end

    assert_nil attachment.markitdown_preview_content
  end

  def test_delete_markitdown_preview_logs_error
    attachment = create_attachment(
      'sample_old.xls',
      'application/vnd.ms-excel'
    )

    FileUtils.stubs(:rm_f)
             .raises(StandardError.new('delete failed'))

    Rails.logger.expects(:error).with do |message|
      message.include?('Could not remove MarkItDown preview') &&
        message.include?('delete failed')
    end

    attachment.send(:delete_markitdown_preview)
  end

  def test_markitdown_preview_content_returns_nil_when_not_previewable
    attachment = create_attachment(
      'sample_old.xls',
      'application/vnd.ms-excel'
    )

    attachment.stubs(:markitdown_previewable?)
              .returns(false)

    assert_nil attachment.markitdown_preview_content
  end

  def test_markitdown_preview_cache_path
    attachment = create_attachment(
      'sample_old.xls',
      'application/vnd.ms-excel'
    )

    expected =
      File.join(
        RedmineMarkitdownPreview.preview_storage_path,
        "#{attachment.digest}_#{attachment.filesize}.md"
      )

    assert_equal expected,
                 attachment.markitdown_preview_cache_path
  end

  def test_convert_logs_error_when_command_fails
    converter = RedmineMarkitdownPreview::Converter

    converter.stubs(:available?).returns(true)

    status = mock
    status.stubs(:success?).returns(false)
    status.stubs(:exitstatus).returns(123)

    Process.stubs(:spawn).returns(1234)
    Process.stubs(:wait2).returns([1234, status])

    converter.logger.expects(:error).with do |message|
      message.include?('MarkItDown preview generation failed') &&
        message.include?('(123)')
    end

    source = plugin_fixture_file('mail_sample.msg')

    Dir.mktmpdir do |dir|
      target = File.join(dir, 'preview.md')

      assert_nil converter.convert(source, target)
    end
  end

  def test_available_returns_false_when_command_fails
    converter = RedmineMarkitdownPreview::Converter

    converter.reset_settings_cache!

    Process
      .stubs(:spawn)
      .raises(Errno::ENOENT)

    converter.logger.expects(:warn)

    assert_equal false, converter.available?
  end

  def test_terminate_process_group
    converter = RedmineMarkitdownPreview::Converter

    Process.expects(:kill)
           .with('KILL', -123)

    Process.expects(:wait)
           .with(123)

    converter.send(
      :terminate_process_group,
      123
    )
  end

  def test_terminate_process_group_handles_echild
    converter = RedmineMarkitdownPreview::Converter

    Process.stubs(:kill)
           .raises(Errno::ECHILD)

    assert_nil(
      converter.send(
        :terminate_process_group,
        123
      )
    )
  end
end
