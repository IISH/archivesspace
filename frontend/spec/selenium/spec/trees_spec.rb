# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Tree UI' do
  before(:all) do
    @repo = create(:repo, repo_code: "trees_test_#{Time.now.to_i}")
    set_repo @repo

    @viewer_user = create_user(@repo => ['repository-viewers'])

    @driver = Driver.get
    @driver.login_to_repo($admin, @repo)
  end

  before(:each) do
    @r = create(:resource)
    @a1 = create(:archival_object, resource: { ref: @r.uri })
    @a2 = create(:archival_object, resource: { ref: @r.uri })
    @a3 = create(:archival_object, resource: { ref: @r.uri })
    @a4 = create(:archival_object, resource: { ref: @r.uri })

    @a4.set_suppressed(true)

    @driver.get_edit_page(@r)
    @driver.wait_for_ajax
  end

  after(:all) do
    @driver ? @driver.quit : next
  end

  it 'can add a sibling' do
    expect(@driver.find_elements(css: '.root-row').length).to eq(1)
    expect(@driver.find_elements(css: '.largetree-node').length).to eq(4)

    tree_click(tree_node(@a3))

    tree_add_sibling

    @driver.find_hidden_element(:css, '#archival_object_title_').wait_for_class('initialised')
    @driver.execute_script("$('#archival_object_title_').data('CodeMirror').setValue('Sibling')")

    @driver.find_element(:id, 'archival_object_level_').select_option('item')
    @driver.click_and_wait_until_gone(:css, "form#archival_object_form button[type='submit']")
    @driver.wait_for_ajax

    expect(@driver.find_elements(css: '.largetree-node').length).to eq(5)

    # reload the parent form to make sure the changes stuck
    @driver.get("#{$frontend}/#{@r.uri.sub(%r{/repositories/\d+}, '')}/edit")
    @driver.wait_for_ajax

    expect(@driver.find_elements(css: '.root-row').length).to eq(1)
    expect(@driver.find_elements(css: '.largetree-node').length).to eq(5)
  end

  # unpend when frequent random failures are resolved
  xit 'can retain location hash when sidebar items are clicked' do
    tree_click(tree_node(@a1))
    expect(@driver.current_url).to match(/::archival_object/)
    @driver.find_element(css: ".sidebar-entry-notes a").click
    assert(5) { expect(@driver.current_url).to match(/::archival_object/) }
  end

  it 'shows the suppressed tag only for suppressed records' do
    expect(@driver.find_elements(css: '#tree-container > .table.root > .table-row-group > div > .title > a.record-title > span.label.label-info').length).to eq(1)

    expect(@driver.find_element(css: '#tree-container > .table.root > .table-row-group > div:nth-of-type(5) > .title > a.record-title > span.label.label-info').text).to eq('Suppressed')
  end
end
