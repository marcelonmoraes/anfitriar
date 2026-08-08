class AddUniqueIndexesToCategories < ActiveRecord::Migration[8.1]
  def change
    add_index :categories, [ :host_id, :name ], unique: true,
              where: "host_id IS NOT NULL",
              name: "index_categories_on_host_id_and_name_unique"
    add_index :categories, :name, unique: true,
              where: "host_id IS NULL",
              name: "index_categories_on_name_standard_unique"
  end
end
