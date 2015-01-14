import extObject;


/*
 * The named transactions must implement this interface
 */
abstract class Transaction(RT) {
  RT execute();
}





/*
 * All the operations that transit on the network
 */
abstract class Operation {
  ExtObject execute();
}
