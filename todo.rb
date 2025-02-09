require "sinatra"
require "sinatra/reloader"
require "tilt/erubi"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

helpers do
  def flash_message(name)
    if session[name]
      <<~MESSAGE
      <div class = "flash #{name}">
        <p>#{session.delete(name)}</p>
      </div>
      MESSAGE
    end
  end
end

def bad_size?(input)
  !(1..100).cover? input.size
end

def existing_list?(input)
  session[:lists].any? { |hash| hash[:name] == input } 
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

get "/lists/new" do
  erb :new_list
end

post "/lists" do
  list_name = params[:list_name].strip

  if bad_size?(list_name)
    session[:error] = "The list name must be between 1 and 100 characters."
    erb :new_list, layout: :layout

  elsif existing_list?(list_name)
    session[:error] = "The list name must be unique."
    erb :new_list, layout: :layout
    
  else  
    session[:lists] << {name: list_name , todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end