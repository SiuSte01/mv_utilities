#!/opt/local/marketview/conda/1/envs/master/bin/python

import logging
import argparse
import sys
import os
import signal
import time
import pickle
from champs import error_logger, utility, stdlib

utility.mail(emails='stephen.siu@risk.lexisnexis.com',
             message="LDS updated",
             subject="LDS order form updated")
