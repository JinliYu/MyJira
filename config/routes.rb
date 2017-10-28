Rails.application.routes.draw do
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  resources :boards
  resources :lists
  resources :cards
  resources :tags
  resources :comments
  resources :notifications do
    collection do
        post :mark_as_read
    end
  end
  
  get 'sessions/new'

# For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root 'application#hello'
  get '/signup', to: 'users#new'
  post '/signup', to: 'users#create'
  get    '/login',   to: 'sessions#new'
  post   '/login',   to: 'sessions#create'
  delete '/logout',  to: 'sessions#destroy'
  resources :users
  get '/search/user', to: 'users#search'
  get '/enroll', to:'boards#enroll'
end
