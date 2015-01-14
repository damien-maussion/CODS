import std.traits;
import std.conv;

/**
* This type is able to contain any object of any type
**/
struct ExtObject {

  /** 
  * transforms any structure/union/base type into a class
  **/
  private class toClass(T) {
    T t;

    this(T t) {
      this.t = t;
    }

    T get() {
      return t;
    }

    override string toString() {
      return to!string(t);
    }
  }

  /** 
  * stores the content of the object
  **/
  Object obj;

  /** 
  * expressions such as o.toString() works as if T : ExtObject
  **/
  alias obj this;

  /** 
  * stores values : object = x
  **/
  T opAssign(T)(T x) {
    obj = cast(Object)(new toClass!T(x));
    return x;
  }

  T opAssign(T : Object)(T x) {
    obj = cast(Object)(x);
    return x;
  }

  T opAssign(T : ExtObject)(T x) {
    obj = x.obj;
    return x;
  }

  /** 
  * retrieves values : x = cast(T)(object)
  **/
  T opCast(T)() const {
    toClass!T objCl = cast(toClass!T)(obj);
    return objCl.get();
  }

  T opCast(T:Object)() const {
    return cast(T)(obj);
  }

  void opCast(T : void)() const { }

  T opCast(T:ExtObject)() const {
    return this;
  }

}
