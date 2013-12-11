Sequel.migration do
  up do
    run 'UPDATE items
          JOIN products using(p_id)
          SET
            items.i_price = products.price;
        '
  end

  down do
  end
end



