class AddAsaasCustomerToHosts < ActiveRecord::Migration[8.1]
  def change
    add_column :hosts, :asaas_customer_id, :string
    add_column :hosts, :cpf_cnpj, :string
    add_column :hosts, :postal_code, :string
    add_column :hosts, :address_number, :string

    add_index :hosts, :asaas_customer_id, unique: true
  end
end
