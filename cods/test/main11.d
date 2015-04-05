import std.stdio;
import std.conv;
import std.container;
import core.thread;

import orange.serialization._;
import cc;
import observer;

import networkSimulator;
import network;
import std.typecons;
import std.typetuple;

import transactions;

import std.variant;

import std.algorithm: canFind;

import pegged.grammar;


mixin(grammar(`
Rule:
	Boolean 		<- OrExpr / ForAllExpr
	OrExpr  		<- AndExpr (:space* :"||" :space* AndExpr)*
	AndExpr 		<- NotExpr (:space* :"&&" :space* NotExpr)*
	NotExpr 		<- "!"? Primary
	ForAllExpr  <- :"ForAll" :space identifier :space :":" :space identifier :space Primary
	Primary 	  <- :'(' :space* Boolean :space* :')'/ InExpr
	InExpr       	<- GetterExpr :space :"in" :space identifier
	GetterExpr   	<- identifier:'.'identifier / identifier:"->"identifier / identifier
`));

import uc;
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


/**********************************
 *
 * T needs to override :
 *  override bool opEquals(Object o)
 *  override size_t toHash() 
 *
 **********************************/
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


public interface ITypeMapper{
  public Axiom interprete(ParseTree p);
}

public class TypeMapper(T : Gettable) : ITypeMapper{
  public override Axiom interprete(ParseTree p){
    switch (p.name){
      case "Rule.ForAllExpr":
        return new ForAll!T(p.matches[0], p.matches[1]);
      case "Rule.InExpr":
        if (p.children.length == 1){

          auto child = p.children[0];
            
          if (child.successful){
            string setName = p.matches[p.matches.length-1];
            string attr = (child.matches.length==1) ? "" : child.matches[1];
            return new In!T(new Getter!T(child.matches[0], null, attr), setName);
          }
          
          return null;
        }
        return null;
      default:
          return null;
    }
  }
}

public class TypeResolver{
  public ITypeMapper[string] iTypeMappers;

  public void addTypeMapper(T)(string s){
    Network.registerType!(TypeMapper!T);
    iTypeMappers[s] = new TypeMapper!T();
  }

  public ITypeMapper getTypeMapper(T)(string s){
    return iTypeMappers[s];
  }

  public ITypeMapper[string] getAll(){
    return iTypeMappers;
  }
}

public class Interpreter{

  public TypeResolver typeResolver;

  public this(){
    typeResolver = UC.connect!TypeResolver("TypeResolver");  
  }

  public void addTypeMapper(T)(string s){
    typeResolver.addTypeMapper!T(s);
  }
  
  public Axiom interprete(string s){
    return interprete(Rule(s));
  }

  public Axiom interprete(ParseTree p){
    switch (p.name) {
        case "Rule":
            return interprete(p.children[0]);
        case "Rule.Boolean":
            return interprete(p.children[0]);
        case "Rule.OrExpr":
            return interprete(p.children[0]);
        case "Rule.ForAllExpr":

          Axiom f = typeResolver.getTypeMapper!string(p.matches[1]).interprete(p);

          auto a = interprete(p.children[0]);
          if (a is null || f is null)
            return null;
          (cast(IForAll)f).setAxiom(a);
          return f;
        case "Rule.AndExpr":
          Axiom[] tab;
          foreach (ParseTree child; p.children){
            auto a = interprete(child);
            if (!(a is null))
              tab ~= a;
          }
          if (tab.length==0)
            return null;
          return new And(tab);
        case "Rule.NotExpr":
          auto a = interprete(p.children[0]);
          if (p.matches[0] =="!" && !(a is null))
            return new No(a);
          return a;
        case "Rule.Primary":
            return interprete(p.children[0]);
        case "Rule.InExpr":
          if (p.matches.length > 0 ){
            string setName = p.matches[p.matches.length-1];
            return typeResolver.getTypeMapper!void(setName).interprete(p);
          }
          return null;
        case "Rule.Getter":
          return null;
        default:
            return null;
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
      SetManager sm  = new SetManager();
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
      SetManager sm = new SetManager();
      sm.notify(new Event!T(setName, "del", elem));
    }
  }

  public Set!stringPrim rules;

  Interpreter interpreter;

  public this(){
    rules = UC.connect!(Set!stringPrim)("rules");
    interpreter = new Interpreter();
  }

  public void notify(IEvent e){
    
    foreach (stringPrim rule; rules.read()){
      Axiom a = interpreter.interprete(rule.s);

      if (!(a is null)){
        a.force(e);
      }
        
    }
  }

  public Set!T createSet(T)(string setName){
    Network.registerType!(TransIns!(T));
    Network.registerType!(TransDel!(T));

    interpreter.addTypeMapper!T(setName);
    
    return UC.connect!(Set!T)(setName);
  }

  public void addRule(string s){
    rules.ins(new stringPrim(s));
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

  SetManager sm  = new SetManager();
  Set!stringPrim students = sm.createSet!stringPrim("students");
  Set!Team teams = sm.createSet!Team("teams");

  sm.ins!stringPrim("rules", new stringPrim("ForAll x : teams (x.t1 in students && x.t2 in students)"));

  sm.ins!stringPrim("students", new stringPrim("a"));
  sm.ins!stringPrim("students", new stringPrim("b"));
  sm.ins!stringPrim("students", new stringPrim("c"));
  sm.ins!stringPrim("students", new stringPrim("d"));
  
  sm.ins!Team("teams", new Team(new stringPrim("a"), new stringPrim("b")));

  Thread.sleep(dur!("msecs")(500));
  sm.del!stringPrim("students", new stringPrim("d"));
 
  Thread.sleep(dur!("msecs")(500));
  writeln("affichage : ", students.read());
  writeln("affichage : ", teams.read());
  
}

/**********************************
 *
 * Code for the second process
 *
 **********************************/

void ex2 () { 
  SetManager sm  = new SetManager();
  Set!stringPrim students = sm.createSet!stringPrim("students");
  Set!Team teams = sm.createSet!Team("teams");

  sm.ins!stringPrim("rules", new stringPrim("ForAll x : teams (x.t1 in students && x.t2 in students)"));

  sm.ins!stringPrim("students", new stringPrim("a"));
  sm.ins!stringPrim("students", new stringPrim("b"));
  sm.ins!stringPrim("students", new stringPrim("c"));
  sm.ins!stringPrim("students", new stringPrim("d"));
  
  sm.ins!Team("teams", new Team(new stringPrim("a"), new stringPrim("b")));

  Thread.sleep(dur!("msecs")(500));
  sm.ins!Team("teams", new Team(new stringPrim("c"), new stringPrim("d")));
 
  Thread.sleep(dur!("msecs")(500));
  writeln("affichage : ", students.read());
  writeln("affichage : ", teams.read());

}


class Gettable{
  Variant get(string attr){
    return Variant("");
  }
}

class Pair(T) : Gettable {
  public T t1;
  public T t2;
  public this(){};
  public this(T a, T b){t1=a; t2=b;}
  public override Variant get(string attr){
    if (attr=="t1")
      return Variant(t1);
    if (attr=="t2")
      return Variant(t2);
    return Variant(this);
  }
  public override string toString(){return "{"~ to!string(t1) ~","~to!string(t2)~"}";} 
}

class Team : Gettable {
  public stringPrim t1;
  public stringPrim t2;
  public this(){};
  public this(stringPrim a, stringPrim b){t1=a; t2=b;}
  public override Variant get(string attr){
    if (attr=="t1")
      return Variant(t1);
    if (attr=="t2")
      return Variant(t2);
    return Variant(this);
  }
  public override string toString(){
    return "{"~ t1.s ~","~t2.s~"}";
  } 
  override bool opEquals(Object o){
    Team team = cast(Team)o;
    return t1 == team.t1 && t2 == team.t2;
  }
  override size_t toHash() { return (t1.s~t2.s).length; }
}


class stringPrim : Gettable{
  public string s;

  public this(string s1){s=s1;}
  public this(){s="";}
  public override Variant get(string attr){
    return Variant(this);
  }
  public override string toString(){
    return s;
  }
  override size_t toHash() { return s.length; }
  
  override bool opEquals(Object o){
    return s== (cast(stringPrim)o).s;
  }
}



interface Axiom{
  public bool test();
  public bool no();
  public void print();
  public bool force(IEvent e);
  public bool forceNo(IEvent e);
  public void replaceGetter(string id, Gettable *ptr);
  public void setSetManager(SetManager *setM);

}

class No : Axiom{
  public this(Axiom a){axiom=a;}
  public override bool test(){return axiom.no();}
  public override bool no(){return axiom.test();}
  public override bool force(IEvent e){return axiom.forceNo(e);}
  public override bool forceNo(IEvent e){return axiom.force(e);}
  public override void print(){
    write(" Not(");
    axiom.print();
    write(") => ", test());
  }
  public override void replaceGetter(string id, Gettable *ptr){
    axiom.replaceGetter(id, ptr);
  }
  public void setSetManager(SetManager *setM){sm=setM; axiom.setSetManager(setM);}
  private SetManager *sm;
  private Axiom axiom;
}

class And : Axiom{
  public this(Axiom[] a){tab=a;}
  public override bool test(){
	foreach (Axiom a; tab ){
      if (!a.test())
        return false;
    }
    return true;
  }
  public override bool no(){return !test();}

  public override bool force(IEvent e){
    foreach (Axiom a; tab ){
      if (!a.force(e))
        return false;
    }
    return true;
  }
  
  public override bool forceNo(IEvent e){return false;}

  public override void print(){
  	write(" And [");
      foreach (Axiom a; tab ){
        a.print();
  	  write(", ");		
      }
  	write("] => ", test());
  }
  public override void replaceGetter(string id, Gettable *ptr){
    foreach (Axiom a; tab ){
      a.replaceGetter(id, ptr);
    }
  }
  public void setSetManager(SetManager *setM){
    sm=setM;
    foreach (Axiom a; tab){
      a.setSetManager(setM);
    }
  }
  private SetManager *sm;

  private Axiom[] tab;
}

class In(T) : Axiom{
  public this(T tr, string n){isGetter=false;t=tr; setName=n; }
  public this(Getter!T g, string n){isGetter=true;getter=g; setName=n; }
  public override bool test(){
    Set!T set = UC.connect!(Set!T)(setName);
    if (isGetter){
      return set.read().canFind(getter.get());
    }
    return set.read().canFind(t);
  }
  public override bool no(){return !test();}
  public override bool force(IEvent e){
    Set!T set = UC.connect!(Set!T)(setName);
    if (isGetter){
      auto g = getter.get();
      set.ins(getter.get());
    }
    else{
      set.ins(t);
    }
    return true;
  }
  public override bool forceNo(IEvent e){
    Set!T set = UC.connect!(Set!T)(setName);
    if (isGetter)
      set.del(getter.get());
    else
      set.del(t);
    return true;
  }
  public override void print(){
    Set!T set = UC.connect!(Set!T)(setName);
    if (isGetter)
      write(" (" , getter.get() ," € ",set.read(),") => ", test());
    else
      write( " (" , t ," € ",set.read(),") => ", test());
  }
  public override void replaceGetter(string id, Gettable *ptr){
    if (isGetter)
      getter.setGettable(id, ptr);
  }
  public void setSetManager(SetManager *setM){sm=setM;}
  private SetManager *sm;

  public T t;
  public string setName;
  public Getter!T getter;
  private bool isGetter;
}

public interface IForAll{
  public void setAxiom(Axiom a);
}
public class ForAll(T : Gettable) : Axiom, IForAll{
  public this(string gId, string n, Axiom a=null){
    setName=n;
    getterId=gId;
    setAxiom(a);
  }
  public override bool test(){
    Set!T set = UC.connect!(Set!T)(setName);
    foreach (T t; set.read() ){
      gettable = t;
      if (!axiom.test())
        return false;
    }
    return true;
  }
  public override bool no(){return !test();}
  public override bool force(IEvent e){
    if (e.source == setName){
      if (e.op == "ins"){
        Set!T set = UC.connect!(Set!T)(setName);
        foreach (T t; set.read() ){
          gettable = t;
          if (!axiom.force(e))
            return false;
        }
      }
    }
    else {
      Set!T set = UC.connect!(Set!T)(setName);
      foreach (T t; set.read() ){
        gettable = t;
        if (!axiom.test())
          set.del(t);
      }
    }
    return true;
  }
  public override bool forceNo(IEvent e){
    return false;
  }

  public override void replaceGetter(string id, Gettable *ptr){
    axiom.replaceGetter(id, ptr);
  }

  public void setAxiom(Axiom a){
    axiom = a;
    if (!(a is null))
      axiom.replaceGetter(getterId, cast(Gettable*)&gettable);
  }

  public void print(){
    Set!T set = UC.connect!(Set!T)(setName);
    writeln("forAll t in ", set.read(), "\n{");
    foreach (T t; set.read() ){
      gettable = t;
      axiom.print();
      writeln("");
    }
    writeln("} => ", test());
  }

  public void setSetManager(SetManager *setM){sm=setM;axiom.setSetManager(sm);}
  private SetManager *sm;

  public string getterId;
  public string setName;
  Axiom axiom;
  T gettable;
}

class Getter(T){
  public this(string ident,Gettable *o, string attri){
    id = ident;
    it=o;
    attr=attri;
  }

  public T get(){
  	return it.get(attr).get!T();
  }

  public void setGettable(string n, Gettable *ptr){
    if (id==n)
      it = ptr;
  }

  public string id;
  public Gettable *it;
  public string attr;
}


void main () 
{ 
  //from cc
  Network.registerType!Operation_List;

  Network.registerType!(Operation_Transaction!(void, UC));
  Network.registerType!(Operation_Method!(UC, Set!stringPrim));
  Network.registerType!(Operation_Method!(UC, Set!Team));
  Network.registerType!(Operation_Method!(UC, TypeResolver));

  UC.Type!(Set!stringPrim).registerTypeMem();
  UC.Type!TypeResolver.registerTypeMem();
  UC.Type!(Set!Team).registerTypeMem();


  auto network = new NetworkSimulator!2([
    {
      ex1();
    },{
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
