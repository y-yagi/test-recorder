class CreateTasks < ActiveRecord::Migration[7.0]
  def change
    create_table :tasks do |t|
      t.string :body1
      t.string :body2
      t.string :body3
      t.string :body4
      t.string :body5

      t.timestamps
    end
  end
end
