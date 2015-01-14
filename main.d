import std.stdio;
import std.conv;
import std.container;
import core.thread;

import orange.serialization._;

import networkSimulator;
import network;

import uc;
import transactions;







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


/**********************************
 *
 * Code for the first process
 *
 **********************************/

void ex1 () { 

  Set!string students = UC.connect!(Set!string)("students");
  Set!(Pair!string) teams = UC.connect!(Set!(Pair!string))("teams");

  students.ins("a");
  students.ins("b");
  students.ins("c");
  students.ins("d");

  Pair!string team = {"a", "b"};
  teams.ins(team);

  Thread.sleep(dur!("msecs")(500));
  students.del("d");


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

  Set!string students = UC.connect!(Set!string)("students");
  Set!(Pair!string) teams = UC.connect!(Set!(Pair!string))("teams");

  students.ins("a");
  students.ins("b");
  students.ins("c");
  students.ins("d");

  Pair!string team = {"a", "b"};
  teams.ins(team);

  Thread.sleep(dur!("msecs")(500));
  Pair!string team2 = {"c", "d"};
  teams.ins(team2);

  Thread.sleep(dur!("msecs")(500));
  writeln(students.read());
  writeln(teams.read());

}


void main () 
{ 
  Network.registerType!(TransXY!UC);
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
