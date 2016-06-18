# AirShark for ComputerCraft
## About
AirShark lets you use any computer to sniff network traffic. With powerful functions like packet filtering,
live view and packet history it's the ideal tool to debug all your network-based programs.

As the name implies AirShark was originally intended for use with wireless modems, but it
will also happily work with regular wired modems as well.

## Requirements
AirShark will run on any computer in ComputerCraft 1.6 or higher, be it handheld or stationary, advanced or basic.
All it needs is a modem (or more) attached to the computer.

## Usage
Once started, AirShark will present you with a menu from which you can chose what you want it do do. Simply press
the key corresponding to the menu option you want to access. The menu options themselves should be self-explainatory :)

### Packet view
Vou can navigate the packet view using the arrow, home and end keys. The left and right arrow keys will navigate backwards
and forwards respectively through the packtes while the home and end key will jump to the first and last packet respectively.
The up and down arrows will scroll the message.

### Channel filter
AirShark provides a way for you to open multiple channels in one go using a so called channel filter.
A channel filter is a string with a special format and looks a little something like this:
```
1-50,-30,-37-35,-40-45,99
```
This channel filter will open all channels from 1 to 50, except for 30, 35 through 37 and 40 through 45, and channel 99.
As you can see, the syntax is fairly simple:
* Single channels are simply a number
* Blocks of channels (called a range) are denoted by a number followed by a dash followed by anothger number
* Ranges can be defined either way, the smaller number follewed by the larger number or vice versa
* A dash in front of a channel or range excludes it from a larger containing range
* Any character other than numbers and dashes separate channels and ranges from each other
  * In the exaple above the delimiter is a comma but ```1-50 -30 -37-35 -40-45 99``` or ```1-50;-30x-37-35,-40-45 99``` would also work

Note that excluding a channel or range doesn't have any effect if there is no larger range surrounding it.
Also note that the filter is evaluated left to right, with the rightmost expression overriding the leftmost expression.
Consider the following filter:
```
1-10,-20,15-25,-30,40-50,30
```
* The ```-20``` won't do anything as channel 20 isn't part of any range up to this point
* Channel 30 is initially excluded (which again doesn't do anything as there's no range surrounding it) but is then later included,
so channel 30 does end up being opened

#### The 128 channel limit
ComputerCraft allows for only 128 channels to be opened per modem. With complex channel filters, it's very easy to lose count and try
to open more than that. Since AirShark first evaluates the channel filter and then opens the channels in thier natural order, with 
a channel filter like ```250,1-200``` channels 1 through 128 are opened but not channel 250, even though it comes first in the filter.

However, if you have more than one modem attached to the computer, you can open the channels on the modems manually first
and then start AirShark. Or if you're running an advanced computer, you can open the channels in the LUA prompt in a separate tab
even while AirShark is running.

Keep in mind that although AirShark can handle messages from more than one modem, it is only
able to use and apply channel filters to one modem at a time, the other modems have to be controlled by an external program!

### Packet filter
AirShark can evaluate the contents of a packet once it's been captured and decide to keep the packet based on a filter you can set.
By default, every packet is accepted.

Packet filters are really just a LUA function that ultimately returns a true or false value. Writing a packet filter is easy, just
write a statement like you normally would for an ```if``` construct.

Packet filters are limited in a sense that they only have access to the most basic LUA statements and the packet information,
which are as follows:
* ```side``` is the side of the computer to which the modem is attached to
* ```sender``` is the channel the message was sent from
* ```reply``` is the channel to which the receiver is supposed to reply to
* ```message``` is the actual message. Note that this may also be a table!
* ```distance``` is the distance between the two modems
* ```time``` is the time of day, as returned by ```os.time()```, when the packet was recorded
* ```day``` is the in-game day when the packet was recorded

## Advanced calling
You can have AirShark start with the packet and/or channel filter already set, in which case AirShark will immedeatly start
capturing the network traffic. This is useful if you have a computer you use for network debugging, using the same settings
all the time. To do this, call AirShark like this:
```
airshark-ng.lua <channel filter> [packet filter]
```
This will start AirShark with the channel filter and optionally the packet filter already set. AirShark will also automatically
apply the channel filter to the first modem it finds (if there are more than one modem attached) and begin capturing packets.

Note that you can not use spaces in the channel filter if you call AirShark this way!

## Planned features
* [ ] Graphical User Interface
* [ ] Save and load channel and packet filters
* [ ] Make channel filters able to handle more than one modem