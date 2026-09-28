Rails.application.routes.draw do
  get "/health", to: "health#show"
  post "/api/auth/login", to: "api/auth#login"
  get "/api/auth/demo-credentials", to: "api/auth#demo_credentials"
  get "/api/auth/me", to: "api/auth#me"

  devise_for :users, :controllers => { :registrations => "user/registrations" }
  resources :user_stocks, except: [:show, :edit, :update]

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  root 'welcome#index'
  #root 'users#my_portfolio'
  get 'my_portfolio', to: 'users#my_portfolio'
  get 'search_stocks', to: 'stocks#search'
  get 'my_friends', to: 'users#my_friends'
  resource :paper_trading, only: [:show, :create], controller: :paper_trading do
    get :audit_export
    patch :kill_switch
  end
  patch "paper_trading/orders/:id/approve", to: "paper_trading#approve", as: :approve_paper_order
  patch "paper_trading/orders/:id/cancel", to: "paper_trading#cancel", as: :cancel_paper_order

  namespace :api do
    namespace :v1 do
      resources :market_data, only: :create
      resources :paper_fills, only: :create
      resources :reconciliations, only: :create
    end
  end

  resources :users, only: [:show]
  resources :friendships

  get 'search_friends', to: 'users#search'
  post 'add_friend', to: 'users#add_friend'

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
