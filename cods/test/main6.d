import std.stdio;
import std.conv;
import std.container;
import core.thread;

import orange.serialization._;

import networkSimulator;
import network;

import uc;
import transactions;

import std.algorithm: canFind;

/**********************************
 *
 * Calls ins and del by Setmanager
 * SetManager creates a transaction {action and notification}
 * 
 * ToDo : Trigger creation from a string 
 *
 **********************************/



/**********************************
 *
 * User-defined data type
 *
 **********************************/

struct Pair(T) {
  public T t1;
  public T t2;
}

class Set(T) {
  private bool[T] l;
  public void ins(T t) {
    l[t] = true;
  }
  public void del(T t) {
    l.remove(t);
  }
  public T[] read() {
    return l.keys;
  }

}


class IEvent{
  public string source;
  public string op;
  public void print(){}
}

class Event(T) : IEvent{
  public T arg;

  public this(T)(string src, string o, T ar){
    source=src;
    op=o;
    arg=ar;
  }
  public override void print(){
    writeln("trigg: ", source,".", op,"(", arg,")");
  }
}

class Trigger{
  this(){};
  public void exec(IEvent e){};
}

class TriggerPrint : Trigger{
  public override void exec(IEvent e){
    e.print();
  }
}

class TriggerDelStudent : Trigger{
  public override void exec(IEvent e){
    if (e.op == "del" && e.source=="students"){
      Event!string event = cast(Event!string)e;

      Set!(Pair!string) teams = UC.connect!(Set!(Pair!string))("teams");

      foreach (Pair!string p; teams.read() ){          
        if (p.t1==event.arg || p.t2==event.arg){
          teams.del(p);
        }
      }
    }
  }
}

class TriggerInsTeam : Trigger{
  public override void exec(IEvent e){
    if (e.op == "ins" && e.source=="teams"){
      Event!(Pair!string) event = cast(Event!(Pair!string))e;
      
      Set!string students = UC.connect!(Set!string)("students");

      if (!students.read().canFind(event.arg.t1)){
        students.ins(event.arg.t1);
      }
      
      if (!students.read().canFind(event.arg.t2)){
        students.ins(event.arg.t2);      
      }
    }
  }
}





class SetManager{

  private class TransIns(T) : Transaction!void {

    private T elem;
    private string setName;
    public this(string name, T e){
      elem = e;
      setName = name;
    }

    public override void execute() {
      Set!T set = UC.connect!(Set!T)(setName);
      set.ins(elem);
      
      SetManager sm  = UC.connect!SetManager("setManager");
      sm.notify(new Event!T(setName, "ins", elem));
    }
  }

  private class TransDel(T) : Transaction!void {

    private T elem;
    private string setName;
    public this(string name, T e){
      elem = e;
      setName = name;
    }

    public override void execute() {
      Set!T set = UC.connect!(Set!T)(setName);
      set.del(elem);
      SetManager sm  = UC.connect!SetManager("setManager");
      sm.notify(new Event!T(setName, "del", elem));
    }
  }


  private Set!Trigger triggers;

  public this(){
    triggers = new Set!Trigger();
  }

  public void notify(IEvent e){
    //write("n");
    foreach (Trigger t; triggers.read()){
      t.exec(e);
    }
  }
  public void addTrigger(Trigger t){
    triggers.ins(t);
  }

  public Set!T createSet(T)(string setName){
    Network.registerType!(TransIns!(T));
    Network.registerType!(TransDel!(T));
    return UC.connect!(Set!T)(setName);
  }

  public void ins(T)(string setName, T elem){
    UC.transaction!void(new TransIns!T(setName, elem));
  }

  public void del(T)(string setName, T elem){
    UC.transaction!void(new TransDel!T(setName, elem));
  }
}



/**********************************
 *
 * Code for the first process
 *
 **********************************/

void ex1 () { 
  SetManager sm  = UC.connect!SetManager("setManager");
  
  sm.addTrigger(new TriggerInsTeam());
  sm.addTrigger(new TriggerDelStudent());

  Set!string students = sm.createSet!string("students");
  Set!(Pair!string) teams = sm.createSet!(Pair!string)("teams");


  Thread.sleep(dur!("msecs")(500));
  
  sm.ins!string("students", "a");
  sm.ins!string("students", "b");
  sm.ins!string("students", "c");
  sm.ins!string("students", "d");

  Pair!string team = {"a", "b"};
  sm.ins!(Pair!string)("teams", team);

  Thread.sleep(dur!("msecs")(500));
  sm.del!string("students", "d");


  Thread.sleep(dur!("msecs")(500));
  writeln(students.read());
  writeln(teams.read());

}

/**********************************
 *
 * Code for the second process
 *
 **********************************/

void ex2 () { 

  SetManager sm  = UC.connect!SetManager("setManager");
  
  sm.addTrigger(new TriggerInsTeam());
  sm.addTrigger(new TriggerDelStudent());

  Set!string students = sm.createSet!string("students");
  Set!(Pair!string) teams = sm.createSet!(Pair!string)("teams");

  Thread.sleep(dur!("msecs")(500));

  sm.ins!string("students", "a");
  sm.ins!string("students", "b");
  sm.ins!string("students", "c");
  sm.ins!string("students", "d");

  Pair!string team = {"a", "b"};
  sm.ins!(Pair!string)("teams",team);

  Thread.sleep(dur!("msecs")(500));
  Pair!string team2 = {"c", "d"};
  sm.ins!(Pair!string)("teams", team2);

  Thread.sleep(dur!("msecs")(500));
  writeln(students.read());
  writeln(teams.read());

}


void main () 
{ 

  Network.registerType!(TriggerPrint);
  Network.registerType!(TriggerInsTeam);
  Network.registerType!(TriggerDelStudent);

  auto network = new NetworkSimulator!2([
    {
      ex1();
    }, {
      ex2();
    }]);
  Network.configure(network);
  network.start();
}
















class Register(T) {
  private T t;
  public void opAssign(T t) {
    this.t = t;
  }
  public T read() {
    return t;
  }
}


/**********************************
 *
 * Code for the first process
 *
 **********************************/


void p1 () { 

  /*
   * Data connection
   **************************/

  Register!int x = UC.connect!(Register!int)("x");
  Register!int y = UC.connect!(Register!int)("y");

  /*
   * Simple method calls
   **************************/

  x = 1;       writeln("* x := 1");
  y = 2;       writeln("* y := 2");

  writeln("  (x=" ~ to!string(x.read()) ~ ", y=" ~ to!string(y.read()) ~ ")");

  /*
   * Anonymous transactions
   **************************/

  UC.anonymousTransaction({
    x = 5;
    y = 6;
    x = 7;
  });
  writeln("* {x := 5; y := 6; x := 7}");

  writeln("  (x=" ~ to!string(x.read()) ~ ", y=" ~ to!string(y.read()) ~ ")");

  /*
   * Convergence
   **************************/

  Thread.sleep(dur!("msecs")(1000));
  writeln("  (x=" ~ to!string(x.read()) ~ ", y=" ~ to!string(y.read()) ~ ")");
}











/**********************************
 *
 * Code for the second process
 *
 **********************************/

void p2 () {  

  /*
   * Data Connection
   **************************/
  Register!int x = UC.connect!(Register!int)("x");
  Register!int y = UC.connect!(Register!int)("y");

  /*
   * Simple method calls
   **************************/

  x = 3;       writeln("\t\t\t\t* x := 3");
  y = 4;       writeln("\t\t\t\t* y := 4");

  writeln("\t\t\t\t  (x=" ~ to!string(x.read()) ~ ", y=" ~ to!string(y.read()) ~ ")");

  /*
   * Named transactions
   **************************/

  UC.transaction!void(new TransXY!UC()); 
  writeln("\t\t\t\t* y := 10*x");

  writeln("\t\t\t\t  (x=" ~ to!string(x.read()) ~ ", y=" ~ to!string(y.read()) ~ ")");

  /*
   * Convergence
   **************************/

  Thread.sleep(dur!("msecs")(500));
  writeln("\n---------------------------------------------\n");
  Thread.sleep(dur!("msecs")(500));
  writeln("\t\t\t\t  (x=" ~ to!string(x.read()) ~ ", y=" ~ to!string(y.read()) ~ ")");
}




/**********************************
 *
 * Transaction declaration
 *
 **********************************/

class TransXY(CC) : Transaction!void {
  public override void execute() {
    Register!int x = UC.connect!(Register!int)("x");
    Register!int y = UC.connect!(Register!int)("y");
    y = 10 * x.read();
  }
}
