require "sinatra"
require "sinatra/reloader"
require "tilt/erubi"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

get "/lists" do
  @lists = session[:lists]
  p session[:success]
  erb :lists, layout: :layout
end

get "/lists/new" do
  erb :new_list
end

post "/lists" do
  session[:lists] << {name: params[:list_name], todos: []}
  session[:success] = "The list has been created."
  redirect "/lists"
end