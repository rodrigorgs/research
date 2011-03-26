Sequel.migration do
  up do
    # Commit
    create_table :commit do
      primary_key :id
      foreign_key :project_id, :project 
      foreign_key :author_id, :author
      String :hash, :size => 40
      DateTime :time
      String :message

      unique [:hash, :project_id]
    end
  
    # Developer
    create_table :developer do
      primary_key :id
      String :name, :unique => true, :index => true
    end
    
    # Project
    create_table :project do
      primary_key :id
      String :name, :unique => true, :index => true
    end
    
    # Repository File
    create_table :repofile do
      primary_key :id
      foreign_key :project_id, :project
      String :path

      unique [:path, :project_id]
    end
    
  end  
end