module evx.misc.test;

import std.exception; 

void error (T)(lazy T event) {assertThrown!Error (event);}
void no_error (T)(lazy T event) {assertNotThrown!Error (event);}