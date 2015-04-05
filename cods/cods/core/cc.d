import std.stdio;

import extObject;
import observer;
import transactions;
import network;

interface ConsistencyCriterionImplementation {
  static void executeOperation(Operation);

  public abstract static class SharedObject(T) : T {
    ExtObject executeMethod(Functor!T);
  }
}




interface InternalObject {
  Pointer get_pointer();
}


interface TypedInternalObject(T) : InternalObject {
  ExtObject applyMethod(Functor!T f);
}





class Operation_List : Operation {
  

  Operation[] operations = [];
  
  void addOperation(Operation op) {
    operations[operations.length++] = op;
  }
  
  override ExtObject execute() {
    ExtObject o;
    for(int i = 0; i < operations.length; i++) {
      o = operations[i].execute();
    }
    return o;
  }
}





class Operation_Method(CC, T) : Operation {
  

  Pointer pointer;
  Functor!T functor;
  
  this(Pointer pointer, Functor!T functor) {
    this.pointer = pointer;
    this.functor = functor;
  }

  override ExtObject execute() {
    CC.Type!T t = CC.connect!T(pointer.name);
    ExtObject o = t.applyMethod(functor);
    return o;
  }
}




class Operation_Transaction(RT, CC) : Operation {
  

  Transaction!RT t;
  this(Transaction!RT t) {
    this.t = t;
  }
  override ExtObject execute() {
    ExtObject o;
    CC.getInstance().remoteExecution = true;
    o = t.execute();
    CC.getInstance().remoteExecution = false;
    return o;
  }
}



class Operation_Transaction(RT:void, CC) : Operation {
  
  Transaction!void t;
  this(Transaction!void t) {
    this.t = t;
  }
  override ExtObject execute() {
    ExtObject o;
    CC.getInstance().remoteExecution = true;
    t.execute();
    CC.getInstance().remoteExecution = false;
    return o;
  }
}



class Pointer {
  string name;
  this(string name){
    this.name = name;
  }
  string get_name() {
    return name;
  }
  override string toString() {
    return name;
  }
}





class ConsistencyCriterionBase(CCI : ConsistencyCriterionImplementation) {

  alias CC = ConsistencyCriterionBase!(CCI);

  static {
    private __gshared CC cc;
    public CC getInstance() {
      if(!cc) {
        cc = new CC();
      }
      return cc;
    }

    Type!T connect(T)(string name) {
      return getInstance().getSharedObject!T(name);
    }
    

    RT transaction(RT)(Transaction!RT t) {
      Operation op = new Operation_Transaction!RT(t);
      ExtObject o = getInstance().executeOperation(op);
      return cast(RT)(o);
    }
    
    void transaction(RT:void)(Transaction!void t) {
      Operation op = new Operation_Transaction!(void, CC)(t);
      getInstance().executeOperation(op);
    }
    
    void anonymousTransaction(void delegate () dg) {
      getInstance().startAnonymousTransaction();
      dg();
      Operation opList = getInstance().getOpList;
      getInstance().finalizeAnonymousTransaction();
      getInstance().executeOperation(opList);
    }
    
    void registerSubType(T : Object)() {
      Network.registerType!(T);
    }
    void registerType(T : Object)() {
      Network.registerType!(T);
    }
    
  }
  
  
  private Operation_List opList;
  public bool inTransaction;
  public bool remoteExecution;
  
  private InternalObject objects [string];
  private CCI cci;

  protected this() {
    opList = null;
    inTransaction = false;
    remoteExecution = false;
    cci = new CCI();
  }
  
  /**
   * Get the shared object corresponding to the key
   **/
  Type!T getSharedObject(T)(string name) {
    Type!T x;
    if(name in objects) {
      x = cast(Type!T)(objects[name]);
      // How to manage conflictual types ? Exception or different entries ?
    } else {
      x = new Type!T(name);
      objects[name] = x;
    }
    return x;
  }

  void startAnonymousTransaction() {
    inTransaction = true;
    opList = new Operation_List();
  }

  Operation getOpList() {
    return opList;
  }

  void finalizeAnonymousTransaction() {
    opList = null;
    inTransaction = false;
  }

  
  private ExtObject applyMethodOnObject(T)(Type!T t, Functor!T functor) {
    ExtObject o;
    if(inTransaction) {
      opList.addOperation(new Operation_Method!(CC, T)(t.get_pointer(), functor));
    } else if(remoteExecution) {
      o = new Operation_Method!(CC, T)(t.get_pointer(), functor).execute();
    } else {
      opList = new Operation_List();
      opList.addOperation(new Operation_Method!(CC, T)(t.get_pointer(), functor));
      o = cci.executeOperation(opList);
      opList = null;
    }
    return o;
  }
  
  ExtObject executeOperation(Operation op) {
    return cci.executeOperation(op);
  }

  InternalObject[string] getAllObjects() {
    return objects;
  }

  CCI getImplementation() {
    return cci;
  }

  /**
   * The type handler for the shared objects
   **/

  class Type(T) : CCI.SharedObject!T, TypedInternalObject!T {

    Pointer p;

    this(string s) {
      p = new Pointer(s);
    }
    
    mixin(Observer!(T, Options.extendsType).classCode);
    mixin(Observer!(T, Options.extendsType).newObjectCode);
    
    Pointer get_pointer() {
      return p;
    }
    
    ExtObject applyMethod(Functor!T f) {
      return executeMethod(f); 
    }

  }

  
}
