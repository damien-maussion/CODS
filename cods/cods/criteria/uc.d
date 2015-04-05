import std.stdio;
import std.typecons;
import std.conv;
import std.socket;
import core.thread;
import core.sync.semaphore;


import network;

import transactions;
import cc;
import extObject;
import updateList;
import observer;




class UC_Message : Message {
  private int id; 
  private int clock;
  private Operation op;
  
  this(int clock, int id, Operation op) {
    this.id = id;
    this.clock = clock;
    this.op = op;
  }
  
  override void on_receive() {
    UC.getInstance().getImplementation().receiveMessage(clock, id, op);
  }
}



/*************************************************

Implementation of the Criterion Update Consistency

*************************************************/

class UC_Implementation : ConsistencyCriterionImplementation {
  
  private int id; //local clock
  private int clock; //local clock
  private Update_list!Operation updates; //list of updates in the lexico order
  private Semaphore s; //list of updates in the lexico order

  this() {
    Network.registerType!UC_Message;
    id = Network.getInstance().getID();
    clock = 0;
    updates = new Update_list!Operation();
    s = new Semaphore(1);
  }

  ExtObject executeOperation(Operation op) {
    incr_clock();
    ExtObject o;
    UC_Message m = new UC_Message(get_clock(), id, op);
    //if(not pure query)
    s.wait();
    updates.push(clock, id, op);
    o = executeList();
    //if(not pure update)
    s.notify();
    //if(not pure query)
    Network.getInstance().broadcast(m, false);
    return o;
  }

  
  public int get_clock(){
    return clock;
  }
  
  private void set_clock(int i){
    clock = i;
  }
  
  private void incr_clock(){
    clock =  clock + 1;
  }
  
  
  void receiveMessage(int clock, int id, Operation op) {

    int time = UC.getInstance().getImplementation().get_clock();
    set_clock((time < clock ? clock : time)); //new clock = max (local clock, received clock);
    s.wait();
    updates.push(clock, id, op);
    s.notify();
  }
  
  

  public ExtObject executeList() {
    ExtObject o;
    foreach (InternalObject o; UC.getInstance().getAllObjects()) {
      UC_Object uco = cast(UC_Object)(o);
      uco.initialize();
    }
    auto updates_copy = updates.copy();
    //we apply all the updates seen by the process until now
    while (!updates_copy.isEmpty()){
      auto operation = updates_copy.pull()[2];//pull give the earliest (i,j,f) still in updates
      o = operation.execute();
    }
    return o;
  }

  interface UC_Object {
    void initialize();
  }
  
  override static public class SharedObject(T) : ConsistencyCriterionImplementation.SharedObject!T, UC_Object {
    T t;

    public void initialize() {
      t = new T();
    }

    override public ExtObject executeMethod(Functor!T f) {
      ExtObject o = f.execute(t);
      return o;
    }

  }
}




//class UC : ConsistencyCriterionBase!UC_Implementation {};
alias UC = ConsistencyCriterionBase!UC_Implementation;
