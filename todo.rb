# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubi'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  set :erb, :escape_html => true
end

helpers do
  def flash_message(name)
    return unless session[name]

    <<~MESSAGE
      <div class = "flash #{name}">
      <p>#{session.delete(name)}</p>
      </div>
    MESSAGE
  end

  def list_complete?(list)
    todos = list[:todos]
    todos.all? { |todo| todo[:completed] } && todos.size >= 1
  end

  def list_class(list)
    'class = complete' if list_complete?(list)
  end

  def todos_completed(list)
    todos = list[:todos]
    total_complete = todos.count { |todo| todo[:completed] }

    "<p>#{total_complete} / #{todos.size}</p>"
  end

  def sort_items(items)
    if items == :lists
      @lists.sort_by { |list| list_complete?(list) ? 1 : 0 }
    else
      @todos.sort_by { |todo| todo[:completed] ? 1 : 0 }
    end
  end
end

before do
  session[:lists] ||= []
end

not_found do
  redirect '/lists'
end

get '/' do
  redirect '/lists'
end

get '/lists' do
  @lists = session[:lists]

  erb :lists, layout: :layout
end

get '/lists/new' do
  erb :new_list
end

def invalid_size?(input)
  !(1..100).cover? input.size
end

def existing_name?(input)
  session[:lists].any? { |list| list[:name] == input }
end

def determine_error(input)
  return if @name == input

  if invalid_size?(input)
    session[:error] = 'The list name must be between 1 and 100 characters.'

  elsif existing_name?(input)
    session[:error] = 'The list name must be unique.'
  end
end

def next_id(items)
  max = items.map { |item| item[:id] }.max || -1
  max + 1
end

post '/lists' do
  @lists = session[:lists]
  list_name = params[:list_name].strip
  determine_error(list_name)

  if session[:error]
    erb :new_list, layout: :layout

  else
    session[:lists] << { id: next_id(@lists), name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

def set_up_list
  @lists = session[:lists]
  @id = params['id'].to_i
  @list = @lists.find { |list| list[:id] == @id }
  p @id

  if @lists.none? { |list| list[:id] == @id }
    session[:error] = 'The specified list was not found.'
    redirect '/lists'
  end

  @name = @list[:name]
  @todos = @list[:todos]
end

get '/lists/:id' do
  set_up_list

  erb :todos, layout: :layout
end

get '/lists/:id/edit' do
  set_up_list
  @stored_name = @name

  erb :edit_list
end

post '/lists/:id' do
  set_up_list

  list_name = params[:list_name].strip
  determine_error(list_name)

  if session[:error]
    erb :edit_list, layout: :layout

  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{@id}"

    erb :todos, layout: :layout
  end
end

post '/lists/:id/delete' do
  set_up_list
  @lists.delete(@list)

  if env["HTTP_X_REQUESTED_WITH"] == 'XMLHttpRequest'
     session[:success] = 'The list has been deleted.'
    '/lists'
  
  else
    session[:success] = 'The list has been deleted.'
    redirect '/lists'
  end
end

post '/lists/:id/todos' do
  set_up_list
  @todo = params['todo'].strip

  error = 'Todo must be between 1 and 100 characters'
  session[:error] = error if invalid_size?(@todo)

  if session[:error]
    erb :todos

  else
    session[:success] = 'The todo was added.'
    todo_id = next_id(@todos)
    @list[:todos] << { id: todo_id, name: @todo, completed: false}
    redirect "lists/#{params[:id]}"
  end
end

post '/lists/:id/todos/:todo_id/delete' do
  set_up_list
  todo_id = params[:todo_id].to_i
  todo = @todos.find { |todo| todo[:id] == todo_id }

  @todos.delete(todo)

  if env["HTTP_X_REQUESTED_WITH"] == 'XMLHttpRequest'
    session[:success] = 'The todo has been deleted.'
    status 204
  
  else
    session[:success] = 'The todo has been deleted.'
    redirect "/lists/#{@id}"
  end
end

post '/lists/:id/todos/:todo_id' do
  set_up_list
  todo_id = params[:todo_id].to_i
  todo = @todos.find { |todo| todo[:id] == todo_id }

  is_completed = params[:completed] == 'true'
  todo[:completed] = is_completed

  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@id}"
end

post '/lists/:id/complete_all' do
  set_up_list

  @todos.each do |todo|
    todo[:completed] = true
  end

  session[:success] = 'All todos have been completed.'
  redirect "/lists/#{@id}"
end
