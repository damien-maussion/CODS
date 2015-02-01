import std.stdio;
import std.conv;
import std.container;
import core.thread;
import std.algorithm: canFind;

import orange.serialization._;

import networkSimulator;
import network;

import uc;
import transactions;


/**********************************
 *
 * Triggers with UC and without threads
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


class Set(T){

  private bool[T] l;
  public string name;

  public void ins(T t) {
    l[t] = true;
    //SetManager.getInstance().notify(new Event!T(name, "ins", t));
    //Set!string students = UC.connect!(Set!string)("students");
    //writeln(students.read());
  }
  public void del(T t) {
    l.remove(t);
    //SetManager.getInstance().notify(new Event!T(name, "del", t));
  }
  public void setName(string s){
    name=s;
  }

  public string getName(){
    return name;
  }


  public T[] read() {
    return l.keys;
  }

}

interface Trigger{
  public void exec(IEvent e);
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

class TriggerPrint : Trigger{
  public override void exec(IEvent e){
    e.print();
  }
}

class TriggerDelStudent : Trigger{


  public override void exec(IEvent e){
    if (e.op == "del" && e.source=="students"){
      Event!string event = cast(Event!string)e;
      
      //writeln("need to delete all (",event.arg, ", x) or (x, ",event.arg,")");

      //Set!(Pair!string) teams = SetManager.getInstance().createSet!(Pair!string)("teams");
      Set!(Pair!string) teams = UC.connect!(Set!(Pair!string))("teams");
      //writeln(teams.read());

      Pair!string p={"test", "test"}; 
      teams.ins(p);

      /*
      foreach (Pair!string p; teams.read() ){          
        if (p.t1==event.arg || p.t2==event.arg){
          teams.del(p);
        }
      }
      */
    }
  }
}

class TriggerInsTeam : Trigger{
  public override void exec(IEvent e){
    if (e.op == "ins" && e.source=="teams"){
      Event!(Pair!string) event = cast(Event!(Pair!string))e;
      e.print();
      
      Set!string students = UC.connect!(Set!string)("students");

      //if (!students.read().canFind(event.arg.t1)){
        //writeln("add ", event.arg.t1);
        //writeln(students.read());
        students.ins(event.arg.t1);
      //}
      
      //if (!students.read().canFind(event.arg.t2)){
       // writeln("add ", event.arg.t2);
        students.ins(event.arg.t2);        
     // }
      
    }
  }
}

class SetManager{
  
  public Trigger[] triggers;
  private static SetManager instance = null;

  private this(){}

  public void notify(IEvent e){
    foreach (Trigger t; triggers){
      t.exec(e);
    }
  }
  public void addTrigger(Trigger t){
    triggers~=t;
  }
  public Set!T createSet(T)(string s){

    writeln("a1");
    Set!T set = UC.connect!(Set!T)(s);
    writeln("a2");
/*
    set.setName(s); */
    writeln("a3");
    //set.setSetManager(this);

    return set;
  }

  public static SetManager getInstance(){
    if (instance is null)
      instance = new SetManager();
    return instance;
  }
}


/**********************************
 *
 * Code for the first process
 *
 **********************************/

void ex1 () { 
  
  SetManager sm = SetManager.getInstance();
  
  //sm.addTrigger(new TriggerPrint());
  sm.addTrigger(new TriggerInsTeam());
  sm.addTrigger(new TriggerDelStudent());

  //Set!string students = sm.createSet!(string)("students");
  //Set!(Pair!string) teams = sm.createSet!(Pair!string)("teams");

  Set!string students = UC.connect!(Set!string)("students");
  students.setName("students");
  writeln("&students: ", cast(void*)students);
  Set!(Pair!string) teams = UC.connect!(Set!(Pair!string))("teams");
  teams.setName("teams");
  writeln("&teams: ", cast(void*)teams);

  writeln("Insert students: ");
  students.ins("a");
  students.ins("b");
  students.ins("c");
  students.ins("d");

  writeln("Insert teams: ");
  Pair!string team = {"a", "b"};
  teams.ins(team);
  Pair!string team2 = {"c", "d"};
  teams.ins(team2);

  Pair!string team3 = {"e", "f"};
  UC.anonymousTransaction({
    teams.ins(team3);
    SetManager.getInstance().notify(new Event!(Pair!string)("teams", "ins", team3));
  });

  writeln("Del d:");
  UC.anonymousTransaction({
    students.del("d");
    SetManager.getInstance().notify(new Event!string("students", "del", "d"));
  });

  writeln("\nResult :\n");
  writeln(students.read());
  writeln(teams.read());

}

/**********************************
 *
 * Code for the first process
 *
 **********************************/

void ex2 () { 

  Set!string students = UC.connect!(Set!string)("students");
  Set!(Pair!string) teams = UC.connect!(Set!(Pair!string))("teams");

  Thread.sleep(dur!("msecs")(1500));

  writeln(students.read());
  writeln(teams.read());
}


void main () 
{ 
  Network.registerType!(TransXY!UC);
  auto network = new NetworkSimulator!1([
    {
      ex1();
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
