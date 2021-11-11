

class cmtfile:
    """commented file"""
    def __init__(self, filename):
        self.filename = filename
    def __str__(self):
        return self.filename


class cmttext:
    """commented text"""
    def __init__(self, text):
        self.text = text
    def __str__(self):
        return self.text


class ignfile:
    """ignore file"""
    def __init__(self, filename):
        self.filename = filename
    def __str__(self):
        return self.text


def catfiles(filenames, rootdir,
             include_regexes,
             definition_macro,
             repo,
             result_incguard):
    sepb = "//" + ("**" * 40)
    sepf = "//" + ("--" * 40)
    def banner(s):
        return f"\n\n\n{sepb}\n{sepf}\n// {s}\n// {repo}/{s}\n{sepf}\n{sepb}\n\n"
    def footer(s):
        return f"\n\n// (end {repo}/{s})\n"
    def incguard(filename):
        return f"{filename.replace('.','_').replace('/','_').upper()}_"
    def replace_include(rx, match, line):
        line = line.rstrip()
        cline = rx.sub(f"//{line}", line)
        incl = match.group(1)
        guard = incguard(incl)
        return f"""{cline}
#if !defined({guard}) && !defined(_{guard}) /* {repo}/src/{incl} */
#error "amalgamate: file {incl} must have been included at this point"
#endif /* {guard} - {repo}/src/{incl} */\n
"""
    def append_file(filename):
        s = ""
        with open(filename) as f:
            for line in f.readlines():
                for rx in include_regexes:
                    match = rx.match(line)
                    if match:
                        line = replace_include(rx, match, line)
                s += line
        return s
    def append_cpp(filename):
        return f"""#ifdef {definition_macro}
{append_file(filename)}
#endif /* {definition_macro} */
"""
    def is_src(filename):
        return filename.endswith(".cpp") or filename.endswith(".c")
    out = ""
    for entry in filenames:
        if isinstance(entry, cmttext):
            for line in entry.text.split("\n"):
                out += f"// {line}\n"
        elif isinstance(entry, cmtfile):
            filename = f"{rootdir}/{entry.filename}"
            out += banner(entry.filename)
            with open(filename) as file:
                for line in file.readlines():
                    out += f"// {line}"
        elif isinstance(entry, ignfile):
            pass
        else:
            assert isinstance(entry, str)
            filename = f"{rootdir}/{entry}"
            append = append_cpp if is_src(filename) else append_file
            out += banner(entry)
            out += append(filename)
            out += footer(entry)
    out = f"""#ifndef {result_incguard}
{out}
#endif /* {result_incguard} */
"""
    return out
