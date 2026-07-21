class CreateUserStocks < ActiveRecord::Migration[4.2]
  def change
    create_table :user_stocks do |t|
      t.integer :user_id
      t.integer :stock_id

      t.timestamps null: false
    end
  end
end
