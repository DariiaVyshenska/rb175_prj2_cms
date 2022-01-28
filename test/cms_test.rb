ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(docs_path)

    File.open(user_info_path, "w") do |file|
      file.write('{ admin: "$2a$12$nLiOW6CEFm9Jk1yHFgRrQ.8EztcB5CNUdmCIy7wGVl3eDJnkdxt7S" }')
    end
  end

  def teardown
    FileUtils.rm_rf(docs_path)
    FileUtils.rm(user_info_path)
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { login: "admin" } }
  end

  def create_document(name, content = "")
    File.open(File.join(docs_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document("about.md")
    create_document("history.txt")
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'history.txt'
    assert_includes last_response.body, 'href="/docs/history.txt/edit"'
    assert_includes last_response.body, '/new'
    assert_includes last_response.body, 'New Document'
    assert_includes last_response.body, %q(<button type="submit")
    assert_includes last_response.body, 'delete'
    assert_includes last_response.body, 'Sign In'
    assert_includes last_response.body, 'Sign Up'
    assert_includes last_response.body, 'New Image'
    assert_includes last_response.body, %q(<a href="/images/test_image.jpg)
  end

  def test_file_content
    file_text =  'hello kitty!'
    create_document('some_doc.txt', file_text)
    get "/docs/some_doc.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain;charset=utf-8", last_response["Content-Type"]
    assert_equal file_text, last_response.body
  end

  def test_notapage
    get "/docs/iamnotapage.txt"

    assert_equal 302, last_response.status
    assert_equal 'File does not exist.', session[:msg]

    get '/'
    assert_nil session[:msg]
  end

  def test_markdown_rendering
    file_text =  '#This is going to be a headline'
    create_document('about.md', file_text)

    get '/docs/about.md'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>This is going to be a headline</h1>"
  end

  def test_get_new
    get '/docs/new', {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, 'Add a new document'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_get_new_logout
    get '/docs/new'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:msg]
  end

  def test_create_new_noname
    post '/docs/new', {new_basename: '   ', new_extension: 'txt'}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'A name is required.'
  end

  def test_create_new_wrong_ext
    post '/docs/new', {new_basename: 'smth', new_extension: 'abra'}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Allowed file extensions are:'
  end

  def test_create_new_existing_name
    file_name = 'new_file.txt'
    create_document(file_name)

    post '/docs/new', {new_basename: 'new_file', new_extension: 'txt'}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'new_file.txt already exists. Please, use a unique name.'
  end

  def test_create_new_valid_file
    file_name = 'new_file.txt'
    post '/docs/new', {new_basename: 'new_file', new_extension: 'txt'}, admin_session
    assert_equal 302, last_response.status
    assert_equal "#{file_name} was created.", session[:msg]

    get '/'
    assert_includes last_response.body, file_name
    assert_nil session[:msg]
  end

  def test_create_new_valid_file_logout
    file_name = 'new_file.txt'
    post '/docs/new', {new_basename: 'new_file', new_extension: 'txt'}
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:msg]
  end

  def test_delete_file
    create_document('tmp.txt')
    get '/'
    assert_includes last_response.body, 'tmp.txt'

    post '/docs/tmp.txt/delete', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal 'tmp.txt was deleted.', session[:msg]

    get '/'
    refute_includes last_response.body, %q(href="/tmp.txt")
    assert_nil session[:msg]
  end

  def test_delete_file_logout
    create_document('tmp.txt')
    get '/'
    assert_includes last_response.body, 'tmp.txt'

    post '/docs/tmp.txt/delete', {}
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:msg]
  end

  def test_duplicate_file
    create_document('tmp.txt')
    get '/'
    assert_includes last_response.body, 'tmp.txt'

    post '/docs/tmp.txt/duplicate', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal 'tmp.txt was duplicated.', session[:msg]

    get '/'
    assert_includes last_response.body, 'copy_tmp.txt'
  end

  def test_duplicate_file_logout
    create_document('tmp.txt')
    get '/'
    assert_includes last_response.body, 'tmp.txt'

    post '/docs/tmp.txt/duplicate', {}
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:msg]
  end

  def test_users_signin_page
    get '/users/signin'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, 'Username'
    assert_includes last_response.body, 'Password'
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, %q(<button type='submit'>Sign in)
  end

  def test_login
    post '/signin', username: 'admin', password: 'secret'
    assert_equal 302, last_response.status
    assert_equal 'admin', session[:login]
    assert_equal 'Welcome, admin!', session[:msg]

    get '/'
    assert_includes last_response.body, 'Signed in as admin'
    assert_includes last_response.body, %q(<button type="submit">Sign Out)
  end

  def test_invalid_login
    post '/signin', username: '   ', password: 'secret'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Invalid Credentials'
    assert_nil session[:login]

    post '/signin', username: 'admin', password: '123'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Invalid Credentials'
    assert_nil session[:login]

    post '/signin', username: '123', password: 'secret'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Invalid Credentials'
    assert_nil session[:login]

    post '/signin', username: 'wrong_username', password: 'wrong_pass'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Invalid Credentials'
    assert_nil session[:login]
  end

  def test_signout
    get '/', {}, { "rack.session" => {login: 'admin'} }
    assert_includes last_response.body, "Signed in as admin"

    post '/signout'
    assert_equal 302, last_response.status
    assert_nil session[:login]
    assert_equal 'You have been signed out.', session[:msg]

    get last_response["Location"]
    assert_includes last_response.body, 'Sign In'
  end

  def test_edit_file_page
    file_text =  'initial content'
    create_document('tmp.txt', file_text)

    get '/docs/tmp.txt/edit', {}, admin_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, '<form action'
    assert_includes last_response.body, '<textarea'
    assert_includes last_response.body, '<input id='
    assert_includes last_response.body, 'Edit name'
    assert_includes last_response.body, 'initial content'
  end

  def test_edit_file_page_logout
    file_text =  'initial content'
    create_document('tmp.txt', file_text)

    get '/docs/tmp.txt/edit'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:msg]
  end

  def test_update_file
    file_text =  'initial content'
    create_document('tmp.txt', file_text)

    post '/docs/tmp.txt/edit', { new_file_text: "new content" , new_basename: 'tmp_updated'}, admin_session
    assert_equal 302, last_response.status
    assert_equal "tmp.txt has been updated.", session[:msg]

    get '/docs/tmp_updated.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"

    get '/'
    assert_includes last_response.body, "tmp_updated.txt"
    get '/'
    refute_includes last_response.body, "tmp.txt"
  end

  def test_update_file_text_only
    file_text =  'initial content'
    create_document('tmp.txt', file_text)

    post '/docs/tmp.txt/edit', { new_basename: 'tmp', new_file_text: "new content"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "tmp.txt has been updated.", session[:msg]

    get '/docs/tmp.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_update_file_name_only
    file_text =  'initial content'
    create_document('tmp.txt', file_text)

    post '/docs/tmp.txt/edit', { new_file_text: file_text, new_basename: 'tmp_updated'}, admin_session
    assert_equal 302, last_response.status
    assert_equal "tmp.txt has been updated.", session[:msg]

    get '/'
    get '/'
    assert_includes last_response.body, "tmp_updated.txt"
    refute_includes last_response.body, "tmp.txt"


    get '/docs/tmp_updated.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, file_text
  end

  def test_update_file_wrong_names
    file_text =  'initial content'
    create_document('other_doc.txt', file_text)
    create_document('tmp.txt', file_text)

    post '/docs/tmp.txt/edit', { new_file_text: file_text, new_basename: 'other_doc'}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "other_doc.txt already exists. Please, use a unique name."

    post '/docs/tmp.txt/edit', { new_file_text: file_text, new_basename: '   '}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_update_file_logout
    file_text =  'initial content'
    create_document('tmp.txt', file_text)

    post '/docs/tmp.txt/edit', { edit_file: "new content", new_basename: 'other_doc'}
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:msg]
  end

  def test_signup_page
    get '/signup'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, 'New username:'
    assert_includes last_response.body, 'Repeat Password:'
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, %q(<button type="submit">Sign up)

    get '/signup', {}, admin_session
    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin."
  end

  def test_signup_submit_corrinfo
    post '/signup', username: 'new_user', password1: 'secret',  password2: 'secret'
    assert_equal 302, last_response.status
    assert_equal 'new_user', session[:login]
    assert_equal 'Your accout has been successfully created.', session[:msg]

    get last_response["Location"]
    assert_includes last_response.body, 'Signed in as new_user'
    assert_includes last_response.body, %q(<button type="submit">Sign Out)

    post '/signout'
    post '/signin', username: 'new_user', password: 'secret'
    assert_equal 'new_user', session[:login]
    assert_equal 'Welcome, new_user!', session[:msg]
  end

  def test_signup_incorrect
    post '/signup', username: '    ', password1: 'secret',  password2: 'secret'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'You must enter a new username.'

    post '/signup', username: '', password1: 'secret',  password2: 'secret'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'You must enter a new username.'

    post '/signup', username: '    ', password1: 'secret',  password2: 'secret'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'You must enter a new username.'

    post '/signup', username: 'admin', password1: 'secret',  password2: 'secret'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'This username already exists. Pick another one!'

    post '/signup', username: 'new_user', password1: '',  password2: ''
    assert_equal 422, last_response.status
    assert_includes last_response.body, "The password must be 5 or more characters."

    post '/signup', username: 'new_user', password1: '123456',  password2: ''
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Entered passwords do not match."

    post '/signup', username: 'new_user', password1: '123',  password2: '123'
    assert_equal 422, last_response.status
    assert_includes last_response.body, "The password must be 5 or more characters."

    post '/signup', { username: 'new_user', password1: 'secret',  password2: 'secret' }, admin_session
    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin."
  end


  ######## TESTS for IMAGES
  def test_image_edit_getpage
    get '/images/test_image.jpg/edit'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:msg]

    get '/images/test_image.jpg/edit', {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Current File: test_image.jpg"
    assert_includes last_response.body, %q(<input id="rename_file" type="submit)
  end

  def test_image_edit_post
    post '/images/test_image.jpg/edit'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:msg]

    post '/images/test_image.jpg/edit', {new_basename: 'test_image2'}, admin_session
    assert_equal 302, last_response.status
    assert_equal 'test_image.jpg has been updated.', session[:msg]
    post '/images/test_image2.jpg/edit', {new_basename: 'test_image'}, admin_session
  end

  def test_delete_image
    post '/images/test_image.jpg/delete'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:msg]

    post '/images/test_image.jpg/duplicate', {}, admin_session
    get '/'
    assert_includes last_response.body, 'copy_test_image.jpg'

    post '/images/copy_test_image.jpg/delete', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "copy_test_image.jpg was deleted.", session[:msg]

    get '/'
    get '/'
    refute_includes last_response.body, 'copy_test_image.jpg'
  end

  def test_create_image_copy
    post '/images/test_image.jpg/duplicate'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:msg]

    post '/images/test_image.jpg/duplicate', {}, admin_session
    get '/'
    assert_includes last_response.body, 'copy_test_image.jpg'

    post '/images/copy_test_image.jpg/delete', {}, admin_session

  end

  def test_new_image_layout
    get '/images/new'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:msg]

    get '/images/new', {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Upload Image'
    assert_includes last_response.body, %q(<form action="/images/new" method="post" enctype="multipart/form-data">)
    assert_includes last_response.body, %q(<button type="submit")
  end

  # def test_upload_new_image
  #
  # end
end
