"""
Runs the PyDesigner pipeline
"""

#---------------------------------------------------------------------- 
# Package Management
#----------------------------------------------------------------------
import os # path
import shutil # which
import argparse # ArgumentParser, add_argument
import textwrap # dedent
import numpy # array, ndarray

# Locate mrtrix3 via which-ing dwidenoise
dwidenoise_location = shutil.which('dwidenoise')
if dwidenoise_location == None:
    raise Exception('Cannot find mrtrix3, please see '
        'https://github.com/m-ama/PyDesigner/wiki'
        ' to troubleshoot.')

# Extract mrtrix3 path from dwidenoise_location
mrtrix3path = os.path.dirname(dwidenoise_location)

# Locate FSL via which-ing fsl
fsl_location = shutil.which('fsl')
if fsl_location == None:
    raise Exception('Cannot find FSL, please see '
        'https://github.com/m-ama/PyDesigner/wiki'
        ' to troubleshoot.')

# Extract FSL path from fsl_location
fslpath = os.path.dirname(fsl_location)

#---------------------------------------------------------------------- 
# Parse Arguments
#---------------------------------------------------------------------- 
# Initialize ArgumentParser
parser = argparse.ArgumentParser(
        prog='pydesigner',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent('''\
Appendix
--------
Standard pipeline steps:
    1. dwidenoise (thermal denoising)
    2. mrdegibbs (gibbs unringing)
    3. topup + eddy (undistortion)
    4. b1 bias correction
    4. CSF-excluded smoothing
    5. rician bias correction
    6. normalization to white matter in first b0 image
    7. IRWLLS, CWLLS DKI fit
    8. Outlier detection and removal

See also:
    GitHub      https://github.com/m-ama/PyDesigner
    mrtrix3     https://www.mrtrix.org/
    fsl         https://fsl.fmrib.ox.ac.uk/fsl/fslwiki

                                '''))

# Specify arguments below

# Mandatory
parser.add_argument('dwi', help='the diffusion dataset you would like to '
                    'process',
                    type=str)

# Optional
parser.add_argument('-o', '--output',
                    help='Output location. '
                    'Default: same path as dwi.',
                    type=str)
parser.add_argument('-s', '--standard', action='store_true',
                    default=False,
                    help='Standard preprocessing, bypasses most other '
                    'options. See Appendix:Standard pipeline steps '
                    'for more information. ')
parser.add_argument('--denoise', action='store_true', default=False,
                    help='Run thermal denoising with dwidenoise.')
parser.add_argument('--extent', metavar='n,n,n', default='5,5,5',
                    help='Denoising extent formatted n,n,n (forces '
                    ' denoising. '
                    'Default: 5,5,5.')
parser.add_argument('--eddy', action='store_true', default=False,
                    help='Run FSL eddy. NOTE: requires phase encoding '
                    'specification to run.')
parser.add_argument('--b1correct', action='store_true', default=False,
                    help='Include a bias correction step in dwi '
                    ' preprocessing. ')
parser.add_argument('--scaleb0median', action='store_true',
                    default=False,
                    help='Scale the dwi volume to median b0 CSF intensity '
                    'of 1000 (useful for multiple acquisitions). ')
parser.add_argument('--smooth', action='store_true', default=False,
                    help='Include a CSF-free smoothing step during dwi '
                    'preprocessing. FWHM is usually 1.2 times voxel '
                    'size. ')
parser.add_argument('-d', '--DTI', action='store_true', default=False,
                    help='Include DTI parameters in output folder: '
                    'MD, AD, RD, FA, eigen-values/vectors. ')
parser.add_argument('-k', '--DKI', action='store_true', default=False,
                    help='Include DKI parameters in output folder: '
                    'MK, AK, RK. Will run DTI in addition. ')
parser.add_argument('-w', '--WMTI', action='store_true', default=False,
                    help='Include DKI WMTI parameters (forces DKI): '
                    'AWF, IAS_params, EAS_params. ')
parser.add_argument('--kcumulants', action='store_true', default=False,
                    help='output the kurtosis tensor with W cumulant '
                    'rather than K. ')
parser.add_argument('--mask', action='store_true', default=False,
                    help='Compute a brain mask prior to tensor fitting '
                    'to strip skull and improve efficiency. ')
parser.add_argument('--fit_constraints', default='0,1,0',
                    help='Constrain the WLLS fit. '
                    'Default: 0,1,0.')
parser.add_argument('--rpe_none', action='store_true', default=False,
                    help='No reverse phase encode is available; FSL eddy '
                    'will perform eddy current and motion correction '
                    ' only. ')
parser.add_argument('--rpe_pair', metavar='<reverse PE b=0 image>',
                    help='Specify reverse phase encoding image.')
parser.add_argument('--rpe_all', metavar='<reverse PE dwi>',
                    help='All DWIs have been acquired with an opposite '
                    'phase encoding direction. This information will be '
                    'used to perform a recombination of image volumes '
                    '(each pair of volumes with the same b-vector but '
                    'different phase encoding directions will be '
                    'combined into a single volume). The argument to '
                    'this option is the set of volumes with '
                    'reverse phase encoding but the same b-vectors the '
                    'same as the input image.')
parser.add_argument('--pe_dir', metavar='<phase encoding direction>',
                    help='Specify the phase encoding direction of the '
                    'input series. NOTE: REQUIRED for eddy due to a bug '
                    'in dwipreproc. Can be signed axis number, (-0,1,+2) '
                    'axis designator (RL, PA, IS), or '
                    'NIfTI axis codes (i-,j,k)')

# Use argument specification to actually get args
args = parser.parse_args()

