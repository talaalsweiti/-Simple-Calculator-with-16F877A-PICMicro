# Simple Calculator with 16F877A PICMicro
This project involves building a simple calculator using a 16F877A microcontroller, a push button (P) for data entry, and a 16x2 character LCD. The calculator performs basic mathematical operations on integer numbers and includes user-friendly input handling.

## Project Overview
The calculator's behavior is described as follows:

1. Power-up Display:
    *    The LCD displays "Enter Operation" on the first line.

2. Number Entry:

    *  Clicking the push button (P) increments different parts of the first number (ten thousandths, thousands, hundreds, tens, units).
    *   Leaving P unclicked for over 2 seconds fixes the current part, and the next part becomes incrementable.
    *   Behavior varies based on the current part and the values of higher-order parts.

3. Operation Selection:

    *  After entering the unit value, leaving P unclicked for over 2 seconds selects the mathematical operation (+ by default).
    * Single clicks toggle between addition (+), division (/), and modulo (%).
    *  Leaving P unclicked for over 2 seconds confirms the operation.
4. Second Number Entry:

    * Similar to the first number, user clicks on P increment different parts of the second number.
5. Calculation and Result Display:

    * After entering the second integer number, the system displays the result of the selected operation.
    * The LCD shows the sign "=" and the result, with the first line displaying the message "result."
6. Keep or Restart:

    * After 3 seconds, the system prompts the user with "Keep? [1:Y, 2:N]."
    * Single click (1:Y) allows the user to keep the numbers and change the operation.
    * Double-click (2:N) restarts the calculation process.
7. Operation Change:

    * If the user chooses to keep, the system displays the selected numbers and toggles between operations (+, /, %) with a single click on P.
    * Leaving P unclicked for over 2 seconds confirms the operation.
8. Repeat or Exit:

    * After 3 seconds, the system returns to the previous step or restarts, based on user input.
## Video


https://github.com/talaalsweiti/-Simple-Calculator-with-16F877A-PICMicro/assets/70711756/14c06228-c399-4085-825b-3dd6630c8596


## Team members :
- [Aseel Sabri](https://github.com/Aseel-Sabri)
- [Basil Mari](https://github.com/basilm4r0)
- [Shahd Abu-Daghash](https://github.com/shahdDaghash)
- [Tala Alsweiti](https://github.com/talaalsweiti)
  
