Feature: New packaging

Scenario: Create new packaging order
Given I am logged-in into backend with location WAREHOUSE_2

When I go to labels
And I click "Crear nueva"
And I click "Bajar"
And I go to labels
Then I should see 0 item

When I fill in the following:
  | qty | 1 |
And I click "Crear nueva"
Then I should see 1 item
Then I click "Bajar"

When I go to packaging_list
And I click "Crear nueva"
Then I should see "Escanee el ID"

When I fill with a printed label
And I click "Aceptar"
Then I should see "Liquido corporal Maquillaje TITI Botella 100cc rojo"
When I click "Aceptar"
Then I should see "asignada al producto Liquido corporal Maquillaje TITI Botella 100cc rojo" within ".flash"
And I should see "Liquido corporal Maquillaje TITI Botella 100cc rojo agregado a la orden" within ".flash"
# And within id line_items I should see 1 item 


When I fill with a printed label
And I click "Aceptar"
Then I should see "Liquido corporal Maquillaje TITI Botella 100cc rojo"
When I click "Aceptar"
Then I should see "asignada al producto Liquido corporal Maquillaje TITI Botella 100cc rojo" within ".flash"
And I should see "Liquido corporal Maquillaje TITI Botella 100cc rojo agregado a la orden" within ".flash"
# And within id line_items I should see 2 item 

When I click "Terminar carga"
Then I should see "La orden esta lista para ser verificada" within ".flash"


# dummy
# When I go to packaging_verification_list

When I select a packaging order for verification
Then I should see "Verificando orden de carga"
And I should see 2 item
When I verify all items
When I click "Terminar verificacion"
Then I should see "Imputacion de ordenes al inventario "

When I select a packaging order for allocation
Then I should see the correct title for the allocation of a packaging order
# Then show me the page
# When I click "Imputar orden a Deposito 2"
# Then show me the page
# When I click "Imputar orden a Deposito 2"
# Then show me the page
# When I click "Imputar orden a Deposito 2"
Then The allocation must take place
# Then show me the page

# And I click "Aceptar"
# Then show me the page

# And I click "Terminar verificacion"
# Then I should see "Todavia quedan items pendientes" within ".flash"
# When I click "Destruir"
# Then I should see "Item anulado"

# And I click "Cancelar"
# Then I should see "fue cancelada. Todas las etiquetas y productos fueron dissociados." within ".flash"

