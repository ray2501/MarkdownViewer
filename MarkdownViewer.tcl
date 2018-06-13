#!/usr/bin/env tclsh

#
# A simple Markdown viewer written by Tcl/Tk, v0.1
#

package require Tcl 8.6
package require Tk
package require Tkhtml 3.0
package require Img
package require http
package require tls

set useCmark 1
if { [catch {package require cmark}]==1} {
    package require Markdown
    set useCmark 0
}

# Add https support
http::register https 443 [list ::tls::socket -ssl3 0 -ssl2 0 -tls1 1]

# Setup Window size
wm geometry . 1000x750+20+10
ttk::setTheme "alt"

# Global variable
set basedir ""

# Menu
ttk::frame .menubar -relief raised -borderwidth 2
pack .menubar -side top -fill x

ttk::menubutton .menubar.file -text File -menu .menubar.file.menu
menu .menubar.file.menu -tearoff 0
.menubar.file.menu add command -label Open  -command Open
.menubar.file.menu add command -label Close -command Close
.menubar.file.menu add command -label Quit  -command Exit
ttk::menubutton .menubar.help -text Help -menu .menubar.help.menu
menu .menubar.help.menu -tearoff 0
.menubar.help.menu add command -label About -command HelpAbout
pack .menubar.file .menubar.help -side left

# Contextual Menus
menu .menu
foreach i [list Exit] {
    .menu add command -label $i -command $i
}

if {[tk windowingsystem]=="aqua"} {
    bind . <2> "tk_popup .menu %X %Y"
    bind . <Control-1> "tk_popup .menu %X %Y"
} else {
    bind . <3> "tk_popup .menu %X %Y"
}

# Add Tkhtml widget
pack [ttk::scrollbar .vsb -orient vertical -command {.label yview}] -side right -fill y
html .label -yscrollcommand {.vsb set} -shrink 1 -imagecmd GetImageCmd
.label handler "node" "a" ATagHandler
pack .label -fill both -expand 1

# Handle special key
bind all <F1> HelpAbout

# Handle Key event for TKhtml widget
bind .label <Prior> {%W yview scroll -1 pages}
bind .label <Next>  {%W yview scroll 1 pages}
bind .label <Up>    {%W yview scroll -1 pages}
bind .label <Down>  {%W yview scroll 1 pages}
bind .label <Left>  {%W yview scroll -1 pages}
bind .label <Right> {%W yview scroll 1 pages}
bind .label <Home>  {%W yview moveto 0}
bind .label <End>   {%W yview moveto 1}

bind .label <1>  {
    HrefBinding .label %x %y
}


#=================================================================
# Tkhtml Handler and help function
#=================================================================

proc DownloadData {uri} {
    set token [::http::geturl $uri]
    set data  [::http::data $token]
    set ncode [::http::ncode $token]
    ::http::cleanup $token

    if {$ncode != 200} {
        return -code error "ERROR"
    }

    return $data
}

#
# Copy from https://wiki.tcl.tk/557
#
proc invokeBrowser {url} {
    # open is the OS X equivalent to xdg-open on Linux, start is used on Windows
    set commands {xdg-open open start}
    foreach browser $commands {
        if {$browser eq "start"} {
            set command [list {*}[auto_execok start] {}]
        } else {
            set command [auto_execok $browser]
        }

        if {[string length $command]} {
            break
        }
    }
  
    if {[string length $command] == 0} {
        return -code error "couldn't find browser"
    }

    if {[catch {exec {*}$command $url &} error]} {
        return -code error "couldn't execute '$command': $error"
    }
}

proc HrefBinding {hwidget x y} {
    set node_data [$hwidget node -index $x $y]

    if { [llength $node_data] >= 2 } {
       set node [lindex $node_data 0]
    } else {
       set node $node_data
    }

    if { [catch {set node [$node parent]} ] == 0 } {
        if {[$node tag] == "a"} {
           set uri [string trim [$node attr -default "" href]]

           if {$uri ne "" && $uri ne "#"} {
               if { [string equal -length 8 $uri "https://"]==1 ||
                  [string equal -length 7 $uri "http://"] == 1} {

	          # Invoke a browser if user click a link
	          catch {invokeBrowser $uri}
               }          
           }
       }
    }
}

proc GetImageCmd {uri} {
    if { [file exists $uri]  && ![file isdirectory $uri] } {
        image create photo $uri -file $uri
        return $uri
    }

    set fname [file join $::basedir $uri]
    if { [file exists $fname]  && ![file isdirectory $fname] } {
        image create photo $uri -file $fname
        return $uri
    }

    if { [string equal -length 8 $uri "https://"]==1 || 
	    [string equal -length 7 $uri "http://"] == 1} {

        if { [catch {set data [DownloadData $uri]} ] == 1} {
	    return ""
	}

	if { [catch { image create photo $uri -data $data }]==1 } {
	    return ""
        }

	return $uri
    }

    return ""
}

proc ATagHandler {node} {
    if {[$node tag] == "a"} {
        set href [string trim [$node attr -default "" href]]

	# Only for external link
	if { [string first "#" $href] == -1 &&
		[string trim [lindex [$node attr] 0]] != "name"} {
            $node dynamic set link
        }
    }
}


#=================================================================
# Event Handler
#=================================================================

proc OpenMdFile {filename} {
    set infile [open $filename]
    set md [read $infile]
    close $infile
    if {$::useCmark == 1} {
        set data [cmark::render -to html $md]
    } else {
        set data [::Markdown::convert $md]
    }

    return $data
}

proc ResetAndParse {data} {
    .label reset
    .label parse -final $data

    focus .label
}

proc Open {} {
    set types {
        {{Markdown Files}       {.md}        }
    }
    	
    set openfile [tk_getOpenFile -filetypes $types -defaultextension md]
    	
    if {$openfile != ""} {
        set ::basedir [file dirname $openfile]

        set data [OpenMdFile $openfile]
	ResetAndParse $data
    }	
}

proc Close {} {
    # Just reset it
    .label reset
}

proc Exit {} {
    set answer [tk_messageBox -message "Really quit?" -type yesno -icon warning]
    switch -- $answer {
        yes exit
    }
}

proc HelpAbout {} {
    set ans [tk_messageBox -title "About" -type ok -message \
    "A simple markdown file viewer." ]
}

