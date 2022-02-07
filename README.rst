.. image:: snackabra.svg
   :height: 100px
   :align: center
   :alt: The 'michat' Pet Logo

=================
Snackabra iOS App
=================

For general documentation on Snackabra see:

* https://snackabra.io
* https://snackabra.github.org

If you would like to contribute or help out with the snackabra
project, please feel free to reach out to us at snackabra@gmail.com or
snackabra@protonmail.com


Introduction
------------

This is a template / reference iOS app for snackabra chat client.
The web app (https://github.com/snackabra/snackabra-webclient)
is (probably) more feature complete.


Preliminaries
-------------

This is an early release. It works. But much left to do.

::

   # clone this git
   git clone https://github.com/snackabra/snackabra-ios

   # make sure xcode command line is set up
   xcode-select --install

   # install Fastlane
   brew install fastlane

   # get the pods set up
   pod install

   # use workspace (not projec) as starting point
   open Snackabra.xcworkspace

Gallery (2.4.0+) should come with pod install, but you
might need to manually laod packages for:

  * https://github.com/MessageKit/MessageKit
    'Up to Next Major': 3.7.0
  * https://github.com/suzuki-0000/SKPhotoBrowser
    'Up to Next Major': 7.0.0


Setup
-----

For Fastlane you will need a developer/tester account, and an
app-specific password for the iTunes Transporter
(https://appleid.apple.com/account/manage).



TODO
----

* Fastlane recommends using gemfiles to manage dependency. We haven't
  done that yet (https://docs.fastlane.tools/getting-started/ios/setup/).
* Tried brew install xcodegen, couldn't get it to be happy



LICENSE
-------

Copyright (c) 2016-2022 Magnusson Institute, All Rights Reserved.

"Snackabra" is a registered trademark

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Affero General Public License for more details.

Licensed under GNU Affero General Public License
https://www.gnu.org/licenses/agpl-3.0.html


Cryptography Notice
-------------------

This distribution includes cryptographic software. The country in
which you currently reside may have restrictions on the import,
possession, use, and/or re-export to another country, of encryption
software. Before using any encryption software, please check your
country's laws, regulations and policies concerning the import,
possession, or use, and re-export of encryption software, to see if
this is permitted. See http://www.wassenaar.org/ for more information.

United States: This distribution employs only "standard cryptography"
under BIS definitions, and falls under the Technology Software
Unrestricted (TSU) exception.  Futher, per the March 29, 2021,
amendment by the Bureau of Industry & Security (BIS) amendment of the
Export Administration Regulations (EAR), this "mass market"
distribution does not require reporting (see
https://www.govinfo.gov/content/pkg/FR-2021-03-29/pdf/2021-05481.pdf ).
