class ZCL_HELLO_YJ definition
  public
  create private .

public section.
  class-methods GET_GREETING
    returning
      value(RV_TEXT) type STRING .
protected section.
private section.
ENDCLASS.



CLASS ZCL_HELLO_YJ IMPLEMENTATION.

  METHOD get_greeting.
    rv_text = |Hello, YJ!|.
  ENDMETHOD.

ENDCLASS.
