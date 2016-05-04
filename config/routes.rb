Rails.application.routes.draw do

  get 'ftp/list' => 'ftp#index'

  scope :path=> '/admin' do
    get 'index' => "admin#index"
    get 'produccion' => "admin#production"
    post 'produce' => "admin#produce"
    get 'compras' => "admin#purchases"
    post 'purchase' => 'admin#purchase'
  end

  scope :path => '/bodega' do
    get 'almacenes' => 'warehouse#getWarehouses'
    get 'skusWithStock' => 'warehouse#getSkusWithStock'
    get 'stock' => 'warehouse#getStock'
    post 'moveStock' => 'warehouse#moveStock'
  end

  scope :path => '/api' do 
    get 'consultar/:sku' => 'api#getStockWithSku'
    get 'oc/recibir/:idoc' => 'api#receivePurchaseOrder'
    get 'facturas/recibir/:idfactura' => 'api#receiveBill'
    get 'pagos/recibir/:idtrx' => 'api#receivePayment'
    get 'saldo' => 'api#getAccount' #to test the good connection to the general system service
  end

  root 'pages#home'
  get 'bodegas' => 'pages#warehouses'

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

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
