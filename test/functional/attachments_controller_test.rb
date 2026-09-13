# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class AttachmentsControllerTest < MarkitdownPreview::Test::ControllerCase
  tests AttachmentsController

  def setup
    super
    set_session_user(@admin)
  end

  def test_not_show_docx_with_markitdown_preview
    # docx not in supported_extensions
    attachment = create_attachment('msword.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
    assert_not attachment.markitdown_previewable?
    get :show, params: {id: attachment.id}

    assert_response :success
    assert_equal 'text/html', @response.media_type

    assert_select 'div.filecontent.wiki', count: 0
    assert_select '.nodata', count: 1
    assert_select 'span.pagination.filepreview span.items', text: '(1-1/1)'
  end

  def test_show_xls_with_markitdown_preview
    attachment = create_attachment('sample_old.xls', 'application/vnd.ms-excel')
    get :show, params: {id: attachment.id}

    assert_response :success
    assert_equal 'text/html', @response.media_type

    assert_select 'div.filecontent.wiki'
    assert_select 'h2', text: 'Tabelle1'
    assert_select 'table'
    assert_select 'td', text: '695'
    assert_select '.nodata', count: 0
    assert_select 'span.pagination.filepreview span.items', text: '(1-1/1)'
  end

  def test_show_csv_with_markitdown_preview
    attachment = create_attachment('import_issues.csv', 'text/csv')
    get :show, params: {id: attachment.id}

    assert_response :success
    assert_equal 'text/html', @response.media_type

    assert_select 'div.filecontent.wiki table'
    assert_select 'th', text: /priority;subject;description/
    assert_select 'td', text: /First description/
    assert_select 'td', text: /Child description/

    assert_select '.nodata', count: 0
    assert_select 'span.pagination.filepreview span.items', text: '(1-1/1)'
  end

  def test_show_msg_with_markitdown_preview
    attachment = create_attachment('mail_sample.msg', 'application/vnd.ms-outlook')
    get :show, params: {id: attachment.id}

    assert_response :success
    assert_equal 'text/html', @response.media_type

    assert_select 'div.filecontent.wiki h1', text: 'Email Message'
    assert_select 'strong', text: 'To:'
    assert_select 'strong', text: 'Subject:'
    assert_select 'h2', text: 'Content'
    assert_match 'MSG Test File', @response.body
    assert_match 'time2talk@online-convert.com', @response.body

    assert_select '.nodata', count: 0
    assert_select 'span.pagination.filepreview span.items', text: '(1-1/1)'

    preview_path = attachment.markitdown_preview_cache_path
    assert File.exist?(preview_path)
    assert_operator File.size(preview_path), :>, 100
  end

  def test_show_docx_with_markitdown_preview
    with_markitdown_settings(markitdown_supported_extensions: '.docx') do
      attachment = create_attachment('msword.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
      get :show, params: {id: attachment.id}

      assert_response :success
      assert_equal 'text/html', @response.media_type

      assert_select 'div.filecontent.wiki'
      assert_match('Redmine is a flexible project management web application.', @response.body)
      assert_select 'h1', text: 'Features'
      assert_select 'li', text: 'Multiple projects support'
      assert_select 'li', text: 'Flexible issue tracking system'
      assert_select 'li', text: 'Time tracking'
      assert_select 'p img[alt=""]', count: 1
      assert_select 'p img:not([src])', count: 1

      assert_select '.nodata', count: 0

      assert_select 'span.pagination.filepreview span.items', text: '(1-1/1)'
    end
  end

  def test_show_csv_with_redmine_core_preview
    with_markitdown_settings(markitdown_supported_extensions: '.docx') do
      attachment = create_attachment('import_issues.csv', 'text/csv')
      assert_not attachment.markitdown_previewable?
      get :show, params: {id: attachment.id}

      assert_response :success
      assert_equal 'text/html', @response.media_type

      assert_select 'table.filecontent.syntaxhl'
      assert_select '#L1 td.line-code div', text: /priority;subject;description/
      assert_select '#L2 td.line-code div', text: /First description/
      assert_select '#L3 td.line-code div', text: /Child description/
      assert_select '#L4 td.line-code div', text: /Child of existing issue/

      assert_select '.nodata', count: 0

      assert_select 'span.pagination.filepreview span.items', text: '(1-1/1)'
    end
  end

  def test_destroy_attachment_removes_markitdown_preview_file
    attachment = create_attachment('sample_old.xls', 'application/vnd.ms-excel')
    attachment.markitdown_preview_content
    preview_path = attachment.markitdown_preview_cache_path

    assert File.exist?(preview_path)

    attachment.destroy

    assert_not File.exist?(preview_path)
  end

  def test_not_show_msg_with_max_source_size_limit
    with_markitdown_settings(markitdown_preview_max_source_size: 1) do
      attachment = create_attachment('mail_sample.msg', 'application/vnd.ms-outlook')
      get :show, params: {id: attachment.id}

      assert_response :success
      assert_equal 'text/html', @response.media_type
      assert_select 'div.filecontent.wiki', count: 0
      assert_select '.nodata', count: 1
    end
  end

  def test_should_truncate_preview_when_output_exceeds_limit
    with_markitdown_settings(markitdown_preview_max_output_size: 50) do
      attachment = create_attachment('mail_sample.msg', 'application/vnd.ms-outlook')
      get :show, params: {id: attachment.id}

      assert_response :success
      assert_equal 'text/html', @response.media_type
      assert_select 'div.filecontent.wiki', count: 1
      assert_select '.nodata', count: 0

      preview_path = attachment.markitdown_preview_cache_path
      assert File.exist?(preview_path)
      assert_operator File.size(preview_path), :<, 52
    end
  end

  def test_should_return_nil_when_markitdown_times_out
    Timeout.stubs(:timeout).raises(Timeout::Error)

    attachment = create_attachment('mail_sample.msg', 'application/vnd.ms-outlook')
    get :show, params: {id: attachment.id}

    assert_response :success
    assert_equal 'text/html', @response.media_type
    assert_select 'div.filecontent.wiki', count: 0
    assert_select '.nodata', count: 1

    preview_path = attachment.markitdown_preview_cache_path
    assert_not File.exist?(preview_path)
  end
end
