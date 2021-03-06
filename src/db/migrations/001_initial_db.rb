Sequel.migration do
  up do
    # Commit
    create_table :commit do
      primary_key :id
      foreign_key :project_id, :project 
      foreign_key :author_id, :developer
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

    # Identifiers
    create_table :identifier do
      primary_key :id
      foreign_key :repofile_id, :repofile

      String :name
      Integer :type
        # 0 => module
        # 1 => field
        # 2 => method
    end
    
    # Identifier evolution
    create_table :identifier_evolution do
      primary_key :id
      foreign_key :identifier_id, :identifier
      foreign_key :commit_id, :commit

      Integer :was_added
        # 0 => identifier was removed in that commit
        # 1 => identifier was added in that commit
    end

  end  
end
