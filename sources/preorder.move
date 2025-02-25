
/// Module: preorder
module preorder::preorder{
   use std::string::{String};
  use sui::balance::{Self, Balance,zero};
   use sui::sui::SUI;
   use sui::event;
  
   use sui::coin::{Self,Coin,split, put,take};
   //DEFINE ERROORS
   const ITEMNOTAVAILABLE:u64=0;
   const EALREADYREGISTERED:u64=1;
   const EINSUFFICIENTFUNDS:u64=2;
   const ENOTADMIN:u64=3;
   const EINVALID:u64=4;
    public struct Shop has key,store{
        id:UID,
        shopid:ID,
        name:String,
        itemsinstore:vector<Item>,
        solditems:vector<u64>,
        users:vector<User>,
        itemsoninstaallments:vector<Installments>,
        itemscount:u64,
         balance:Balance<SUI>
    }


    public struct Item has key, store{
        id:UID,
        itemid:u64,
        name:String,
        features:String,
        description:String,
        price:u64,
        sold:bool,
        fullpaid:bool,
        booked:bool
    }

    public struct User has key, store{
        id:UID,
        userid:u64,
        name:String,
       
    }
    
    public struct Installments has key,store{
      id: UID,
      itemid:u64,
      amountpaid:u64,
      targetamount:u64,
      by:address,
      userid:u64
    }
    //define admin cap
    public struct Admin has key{
        id:UID,
        shopid:ID
    }
    //define evnts

    public struct ShopCreated has copy,drop{
        name:String,
        shopid:ID
    }

    public struct ItemAdded has copy,drop{
        name:String,
        id:u64
    }

    public struct UserRegistered has copy,drop{
        name:String
    }
    public struct Withdraw has copy,drop{
        id:ID,
        amount:u64
    }
    //create function

    //create shop

    public entry fun create_shop(name:String,ctx:&mut TxContext){

        let id:UID=object::new(ctx);
        let shopid=object::uid_to_inner(&id);
        //create new shop
        let shop=Shop{
            id,
            shopid,
            name,
            itemsinstore:vector::empty(),
            solditems:vector::empty(),     
            users:vector::empty(),
            itemscount:0,
            balance:zero<SUI>(),
            itemsoninstaallments:vector::empty()
        };

         transfer::transfer(Admin {
          id: object::new(ctx),
          shopid,
    }, tx_context::sender(ctx));
    


//emit event
  event::emit(ShopCreated{
    name,
    shopid
  });

  transfer::share_object(shop);

}

//add items in the sore for users to see them

public entry fun add_items_to_shop(shop:&mut Shop,name:String,features:String,description:String,price:u64,ctx:&mut TxContext){
   
   let newitem=Item{
    id:object::new(ctx),
    itemid:shop.itemscount,
    name,
    features,
    description,
    price,
    sold:false,
    fullpaid:false,
    booked:false
   };

   //add item to the shop

   shop.itemsinstore.push_back(newitem);

   shop.itemscount=shop.itemscount+1;

   event::emit(ItemAdded{
    name,
    id:shop.itemscount-1
   })

}


//update the price of item if te item ids not booked or sold

public entry fun UpdatePrice(shop:&mut Shop,itemid:u64,newprice:u64,_ctx:&mut TxContext){

    //check if the item is available
    assert!(itemid>=shop.itemscount,ITEMNOTAVAILABLE);

    //check if item is already sold or booked 

    assert!(shop.itemsinstore[itemid].sold==false&& shop.itemsinstore[itemid].booked==false,ITEMNOTAVAILABLE);

    //update the item

    shop.itemsinstore[itemid].price=newprice;
}

//user search item for details
 
  public entry fun search_item_in_store_by_name(shop:&mut Shop,name:String,_ctx:&mut TxContext):(String,String,String,u64,u64){

    //loop through the item sto check if there are available

    let mut i:u64=0;

    while(i < shop.itemscount){

        let item=&shop.itemsinstore[i];

        //check by name

        if(item.name==name){

            return (name,item.description,item.features,item.price,i)
        };

        i=i+1;
    };

    //abort the seearch since item is not available
    abort 0
  }

  //register users
  public entry fun register_user (shop:&mut Shop,name:String,ctx:&mut TxContext){

    //chck ifuser is already registered to prevent registering user twice

    //create a while loop to loop all the users

    let mut i:u64=0;
    let totalusers:u64=shop.users.length();

    while(i < totalusers){

        let user=&shop.users[i];

        assert!(user.name!=name,EALREADYREGISTERED);

        i=i+1;
    };

    //register new user

    let newuser=User {
       id:object::new(ctx),
        userid:totalusers,
        name
    };
      shop.users.push_back(newuser);

      event::emit(UserRegistered{
        name
      })
    }
  //users purchahse full item

  public entry fun user_purchase_item_fully(shop:&mut Shop,itemid:u64,amount:&mut Coin<SUI>,ctx:&mut TxContext){

    //check if the item is available

    assert!(shop.itemscount>=itemid,ITEMNOTAVAILABLE);

    //check if user has sufficient funds 


    assert!(amount.value()>=shop.itemsinstore[itemid].price,EINSUFFICIENTFUNDS);

   //chck if item is already sold


   assert!(shop.itemsinstore[itemid].sold==false && shop.itemsinstore[itemid].booked==false,ITEMNOTAVAILABLE);

    //pay for the item and update deails f the item as sold 

    let price=shop.itemsinstore[itemid].price;

    //dedact the amount

    let paid=amount.split(price,ctx);

//add amount to the shop
    put(&mut shop.balance,paid);

    //update the item status as sold

    shop.itemsinstore[itemid].sold=true;

    shop.solditems.push_back(itemid);
  }
  //users purchase slowly
  
   public entry fun purchase_on_installments(shop:&mut Shop,itemid:u64,userid:u64,amount:Coin<SUI>,ctx:&mut TxContext){

      //ensure availability of item iin the shop
      assert!(shop.itemsinstore.length()>= itemid,ITEMNOTAVAILABLE);

     //ensure items is not sold or already booked
     assert!(shop.itemsinstore[itemid].sold==false && shop.itemsinstore[itemid].booked==false,ITEMNOTAVAILABLE);
      //verify if the amount is greater than zero and is less than item actual price of the item
     let targetamount=amount.value();
      assert!(amount.value()>0 && amount.value()< shop.itemsinstore[itemid].price,EINVALID);
      let pbalance = coin::into_balance(amount);

       balance::join(&mut shop.balance, pbalance);
      //perform purchase on installments
      
      let itempurchase=Installments{
        id:object::new(ctx),
        itemid,
        amountpaid:targetamount,
        targetamount:targetamount*2,
        by:ctx.sender(),
        userid
      };
     //update item status
     shop.itemsinstore[itemid].booked=true;
      shop.itemsoninstaallments.push_back(itempurchase);
   }

  //check the balance of the aount remaining untill full purcahse of an item
   
    public entry fun check_remaining_installment_amount(shop:&mut Shop,useraddress:address,_ctx:&mut TxContext):u64{

      //verify the users address
      let mut index:u64=0;
      let length:u64=shop.itemsoninstaallments.length();
      while(index < length){

        let item=&shop.itemsoninstaallments[index];

        if(item.by==useraddress){
          return item.targetamount-item.amountpaid
        };
        index=index+1;
      };
      abort 0
    }

//pay installments
  public entry fun pay_installments(shop:&mut Shop,useraddress:address,amount:&mut Coin<SUI>,ctx:&mut TxContext){
    //verify the users address
      let mut index:u64=0;
      let length:u64=shop.itemsoninstaallments.length();
      while(index < length){

        let item=&shop.itemsoninstaallments[index];

        if(item.by==useraddress){
          //pay amount
          //get remaining balance
          let balance=item.targetamount-item.amountpaid;

         let paid=amount.split(balance,ctx);

         //add amount to the shop
         put(&mut shop.balance,paid);
         let itemid=item.itemid;
         shop.itemsinstore[itemid].sold=true;
        };
        index=index+1;
      };
      abort 0
  }
  //owner withdreeaw amount

   public entry fun withdraw(
        admin: &Admin,      
        shop:&mut Shop,
        amount:u64,
        recipient:address,
         ctx: &mut TxContext,
    ) {

      //verify its admin performing the action

        assert!(admin.shopid==shop.shopid,ENOTADMIN);
        //verify amount is sufficient
      assert!(amount > 0 && amount <= shop.balance.value(),EINSUFFICIENTFUNDS);
        

        //widthdrwaw amount
        let reduct = take(&mut shop.balance, amount, ctx);
        transfer::public_transfer(reduct, recipient);
       
       //emit event

       event::emit(Withdraw{
        id:admin.shopid,
        amount
       })
        
    }
  //users check the remaing amount to full purchase

}

