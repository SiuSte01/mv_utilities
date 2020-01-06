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
			'HGWorkFlow/src': ['dopatients.pl','project_PAC.pl','*.sas'],
				'HGWorkFlow/src/AdvisoryBoard': ['*'],
				'HGWorkFlow/src/INA': ['*'],
				'HGWorkFlow/src/INAA': ['*'],
				'HGWorkFlow/src/Trending': ['*'],
		},
      packages=[
			'HGWorkFlow/src',
				'HGWorkFlow/src/AdvisoryBoard',
				'HGWorkFlow/src/INA',
				'HGWorkFlow/src/INAA',
				'HGWorkFlow/src/Trending'
			#	'aggr/cloneAggr',
			#	'aggr/ina',
			#		'aggr/ina/filter',
			#		'aggr/ina/getInaEntityPcts',
			#		'aggr/ina/qaINA',
			#	'aggr/pxdx',
			#		'aggr/pxdx/buildAllCodesExact'
			],
      scripts=[
			'HGWorkFlow/src/multiBucket.pl'
			],
      zip_safe=False)
