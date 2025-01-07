import re

from core.config import xsschecker
from core.utils import stripper


def jsContexter(script):
    broken = script.split(xsschecker)
    pre = broken[0]
    # Remove everything that is between {..}, (..), "..." or '...'.
    # We eliminate the inline (?s) flags and pass flags=re.DOTALL to the regex call.
    # Equivalent to applying (?s) globally, but in a way Python 3.12 permits.
    pre = re.sub(r'\{.*?\}|\(.*?\)|".*?"|\'.*?\'', '', pre, flags=re.DOTALL)

    breaker = ''
    num = 0

    for char in pre:  # iterate over the remaining characters
        if char == '{':
            breaker += '}'
        elif char == '(':
            breaker += ';)'  # yes, it should be ); but we will invert the whole thing later
        elif char == '[':
            breaker += ']'
        elif char == '/':
            try:
                if pre[num + 1] == '*':
                    breaker += '/*'
            except IndexError:
                pass
        elif char == '}':
            breaker = stripper(breaker, '}')
        elif char == ')':
            breaker = stripper(breaker, ')')
        elif breaker == ']':
            breaker = stripper(breaker, ']')
        num += 1

    return breaker[::-1]  # invert the breaker string
