Sequel.migration do
  up do
    run "ALTER TABLE materials CHANGE `m_notes` `m_notes` text NOT NULL after `m_name`"
  end

  down do
    drop_column :materials, :m_notes
  end
end

