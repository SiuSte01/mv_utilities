from setuptools import setup

setup(name='mvUtil',
      description='Miscellaneous code for Champs products',
      url='unknown',
      use_scm_version=True,
      setup_requires=['setuptools_scm'],
      author='Stephen Siu',
      author_email='stephen.siu@lexisnexis.com',
		package_data={
			'': ['*.tab','*.txt','*.cfg','*.pm','*.sas','*.xlsm'],
			'keatonCode/AB': ['*'],
			'projCode/src': ['dopatients.pl','multiBucket_ABCPM.pl','project_PAC.pl','sendemail.pl','*.sas'],
				'projCode/src/AdvisoryBoard': ['*'],
				'projCode/src/INA': ['*'],
				'projCode/src/Trending': ['*'],
		},
      packages=[
			'keatonCode/AB',
			'projCode/src',
				'projCode/src/AdvisoryBoard',
				'projCode/src/INA',
				'projCode/src/Trending'
			],
      scripts=[
			'keatonCode/AB/AB_Tar_Zip',
			'projCode/src/AdvisoryBoard/combine_inadirs.pl',
			'projCode/src/AdvisoryBoard/combinesummaries_input.pl',
			'projCode/src/AdvisoryBoard/comparesizes_input.pl',
			'projCode/src/INA/makeidlist',
			'projCode/src/mbSplitter.pl',
			'projCode/src/multiBucket.pl',
			'projCode/src/multiBucket_ABCPM.pl',
			'projCode/src/run_ABCPM.pl',
			'projCode/src/Trending/standard_trend',
			'projCode/src/Trending/standard_trend_co'
			],
      zip_safe=False)
