require_relative 'prerequisites'

class AccountsTest < Test::Unit::TestCase
  def setup
    @transaction = Transaction.new("Test transaction", AccountPlan.new($settings))
  end

  def test_should_create_transaction
    assert @transaction.has_plan?
  end

  def test_transaction_cant_be_empty
    DB.transaction(rollback: :always) do
      exception = assert_raise(RuntimeError) {@transaction.save}
      assert_equal(R18n.t.errors.empty_transaction, exception.message) 
    end
end

  def test_should_allow_to_add_operations
    @transaction.add(loc: Location::S1, orig: "Recaudacion", dest: "Caja", ammount: 1000)
    assert @transaction.has_operations? 1
    @transaction.add(loc: Location::S1, orig: "Recaudacion", dest: "Banco", ammount: 500)
    assert @transaction.has_operations? 2
    assert_false @transaction.has_operations? 1
  end


  def test_transaction_description_cant_be_empty
    DB.transaction(rollback: :always) do
      transaction = Transaction.new("     " , AccountPlan.new($settings))
      transaction.add(loc: Location::S1, orig: "Recaudacion", dest: "Caja", ammount: 1000)
      exception = assert_raise(Sequel::ValidationFailed) {transaction.save}
      assert_equal("#{t.fields.t_desc.to_sym} #{t.errors.presence}", exception.message) 
    end
  end


  def test_multiple_transactions
    transaction = Transaction.new("1 Deuda original (desglosar)" , AccountPlan.new($settings))
    transaction.add(orig: "TODOS LOS MATERIALES", dest: "Fondo de comercio a pagar", ammount: 100000)
    puts transaction

    transaction = Transaction.new("2 Venta de mercaderia" , AccountPlan.new($settings))
    transaction.add(orig: "Caja", dest: "Venta por mostrador", ammount: 10000, order: 666, loc: Location::S1)
    transaction.add(orig: "Banco", dest: "Venta por mostrador", ammount: 5000, order: 666, loc: Location::S1)
    transaction.add(orig: "IIBB", dest: "IIBB a pagar", ammount: 450, order: 666, loc: Location::S1)
    transaction.add(orig: "Comisiones a pagar", dest: "Comisiones", ammount: 1500, order: 666, loc: Location::S1)
    puts transaction

    transaction = Transaction.new("2a costo de mercaderia (desglosar)" , AccountPlan.new($settings))
    transaction.add(orig: "Costo mercaderia vendida", dest: "TODOS LOS PRODUCTOS", ammount: 10000, order: 666, loc: Location::S1)
    puts transaction

    transaction = Transaction.new("2b Cobro de comisiones" , AccountPlan.new($settings))
    transaction.add(orig: "Comisiones", dest: "Caja", ammount: 1500, loc: Location::S1)
    puts transaction

    transaction = Transaction.new("3 Compra de impresora" , AccountPlan.new($settings))
    transaction.add(orig: "Bienes de uso", dest: "Tarjeta de credito a pagar", ammount: 1000, loc: Location::W2)
    puts transaction

    transaction = Transaction.new("4 Compra de mercaderia" , AccountPlan.new($settings))
    transaction.add(orig: "Liquido corporal blanco", dest: "Laca", ammount: 230)
    transaction.add(orig: "Liquido corporal rojo", dest: "Laca", ammount: 250)
    transaction.add(orig: "Laca", dest: "Caja", ammount: 480)
    transaction.add(orig: "Fletes", dest: "Caja", ammount: 20)
    puts transaction

    transaction = Transaction.new("5 Aumento del 10% de la mercaderia recien comprada" , AccountPlan.new($settings))
    transaction.add(orig: "Liquido corporal blanco", dest: "Resultado por tenencia", ammount: 23)
    transaction.add(orig: "Liquido corporal rojo", dest: "Resultado por tenencia", ammount: 25)
    puts transaction
  end

  def test_AccountPlan_should_detect_invalid_accounts
    plan = AccountPlan.new($settings)
    plan.load
    assert_false plan.account_exists? "INVALID"
    assert plan.account_exists?("Bienes de cambio")

    assert_false plan.account_valid?("INVALID")
    assert_false plan.account_valid?("Bienes de cambio")
    assert plan.account_valid?("Caja")
  end

  def test_operations_should_not_be_on_same_group
    account_plan = AccountPlan.new($settings)
    transaction = Transaction.new("Compra de liquido corporal mal registrada", account_plan)
    orig = "Liquido corporal blanco"
    dest = "Caja"
    exception = assert_raise(RuntimeError) {transaction.add(orig: orig, dest: dest, ammount: 500)}
    assert_equal(R18n.t.errors.accounts_of_same_group(orig, dest), exception.message) 
  end
end