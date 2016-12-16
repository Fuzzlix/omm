#One More Maketool. A lua based extensible build engine.

OMM is a lua make tool inspired by [lake][]. Its goal is a simpler 
and cleaner syntax, extensibility, portability between different lua 
versions and operating systems. The multitreading is improved compared to 
[lake][]. All makefiles become executed in one and the same sandbox 
environment.  

To see what works and how it works, take a look at the makefiles in the 
examples folder.

Any critics, test reports, and contibutions are welcome.

---

Inspired by and stealing code snippets from Steve Donovan's [lake][].  

Using modified versions of 
Roland Yonaba's [30log][] and
god6or@gmail.com's [os.cmdl][].

Required 3rd party modules: [luafilesystem][], [winapi][]/[luaposix][]

Thanks also to Paul Kulchenko for his great [ZeroBraneStudio][].

[lake]:            https://github.com/stevedonovan/Lake
[30log]:           https://github.com/Yonaba/30log
[os.cmdl]:         https://github.com/edartuz/lua-cmdl
[luafilesystem]:   https://github.com/keplerproject/luafilesystem/
[winapi]:          https://github.com/stevedonovan/winapi
[luaposix]:        https://github.com/luaposix/luaposix/
[ZeroBraneStudio]: https://github.com/pkulchenko/ZeroBraneStudio

---

copyright (C) 2016 Ulrich Schmidt

**The MIT License (MIT)**

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:  
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.  
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

